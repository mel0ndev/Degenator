// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.0;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Degenator} from "./Degenator.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol"; 
import {IUniswapV2Router01} from "./interfaces/IUniswapV2Router01.sol"; 
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol"; 

contract LegendaryDegenStaking is Owned {
    using SafeTransferLib for ERC20;
    
    Degenator public degenator; 
    address public degenatorLP;

    struct StakingBalance {
        uint256 deposited;
        uint256 lpAmount; 
        uint256 stakeStart;
        uint256 stakeEnd;
    }

    struct StakingTier {
        uint256 stakingDuration; 
        uint256 apy;
        uint256 bonus; 
        uint256 unstakeDuration; 
    }

    address public immutable WETH; 
    IUniswapV2Router02 public immutable uniswapRouter; 

    uint256 internal constant DENOMINATOR = 1e19; 
    uint256 internal constant YEAR = 60 * 60 * 24 * 365; 

    mapping(address user => mapping(uint256 pid => StakingBalance)) public stakingBalances; //user can have a per pid staking balance
    mapping(uint256 pid => StakingTier) public tiers; 

    event Staked(address indexed staker, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed staker, uint256 timestamp);
    event Claim(address indexed staker, uint256 amount, uint256 timestamp);

    error ZeroAmount();
	error PeriodNotFinished(); 
	error PeriodStillActive(); 
	error PeriodAlreadyStarted(); 

    constructor(Degenator _degenator, address _degenatorLP, address _router, address _weth) Owned(msg.sender) {
        degenator = _degenator; 
        degenatorLP = _degenatorLP; 
        uniswapRouter = IUniswapV2Router02(_router); 
        WETH = _weth; 
        //initialize staking tiers
        //legendary degenator tier
        tiers[0] = StakingTier({
            stakingDuration: 30 days, 
            apy: 300e17, //300%
            bonus: 900e17, //900%
            unstakeDuration: 60 hours
        }); 
    }

    /* 
    * @notice Stakes a users funds
    * @param amount - the amount to be taken from the user, not including tax
    * @dev the final amount staked is inclusive of the tax
    */
    function stake(uint256 amount, uint256 pid) external {
        if (amount == 0) revert ZeroAmount();
		if (stakingBalances[msg.sender][pid].stakeEnd != 0) revert PeriodStillActive(); 
		
        ERC20(address(degenatorLP)).safeTransferFrom(msg.sender, address(this), amount);
        
        uint256 amount0 = getUnderlyingAmounts(amount); 

        stakingBalances[msg.sender][pid].deposited += amount0;
        stakingBalances[msg.sender][pid].lpAmount += amount; 

        //redepositing more will reset your staking time, this is desired behavior
        stakingBalances[msg.sender][pid].stakeStart = block.timestamp;
        stakingBalances[msg.sender][pid].stakeEnd = 0;

        emit Staked(msg.sender, amount0, block.timestamp);
    }

    /* 
    * @notice Unstakes a users funds and begins the unstaking period 
    * @dev the unstaking period is different per tier
    * @param pid - the pool id (tier) to unstake from
    */
    function unstake(uint256 pid) external {
        StakingBalance storage user = stakingBalances[msg.sender][pid];
		
		if (user.stakeEnd != 0) revert PeriodAlreadyStarted(); 

        user.stakeEnd = block.timestamp;
        emit Unstaked(msg.sender, block.timestamp);
    }

    /* 
    * Claims a users funds after the 3 day holding period is over
	* @dev a user must claim before being able to restake
    */
    function claim(uint256 pid) external returns (uint256) {
        StakingBalance storage user = stakingBalances[msg.sender][pid]; 
        StakingTier memory tier = tiers[pid]; 

        if (block.timestamp < user.stakeEnd + tier.unstakeDuration || user.stakeEnd == 0) {
			revert PeriodNotFinished(); 
		}

        uint256 amountToWithdraw = multiplyStakingBalance(msg.sender, pid) - user.deposited;

        user.deposited = 0;
        user.stakeStart = 0;
        user.stakeEnd = 0;

        //mint the entire amount on unstake minus deposit amount because it is lp token
        degenator.mint(msg.sender, amountToWithdraw);
        //send the user's lp back to them
        ERC20(degenatorLP).safeTransfer(msg.sender, user.lpAmount);

        emit Claim(msg.sender, amountToWithdraw, block.timestamp);

        return amountToWithdraw;
    }

    /* 
    * @notice used to calculate the withdraw balance per user, per pid based on staking time 
    * @param user - the address of the user to calculate the balance for 
    * @param pid - the pool id (tier) to calculate for
    */
    function multiplyStakingBalance(address user, uint256 pid) public view returns (uint256) {
		uint256 end; 
		if (stakingBalances[user][pid].stakeEnd == 0) {
			end = block.timestamp; 
		} else {
			end = stakingBalances[user][pid].stakeEnd; 
		}
        uint256 timeStaked = (end - stakingBalances[user][pid].stakeStart);
        uint256 startingBalance = stakingBalances[user][pid].deposited;

        uint256 hoursStaked = timeStaked / 1 hours;

        
        uint256 a = _getWithdrawAmount(startingBalance, timeStaked, pid); 
        return a; 
    }
    
    /**
     * @notice gets the amount to be withdrawn for the user based on their tier and staking time
     * @param amount - the initial staking deposit amount of the user
     * @param timeStaked - the time spend staked in the pool
     * @param pid - the pool id (tier) we are calculating returns for
     * @return the total amount to be withdrawn, inclusive of initial deposit amount
     */ 
    function _getWithdrawAmount(uint256 amount, uint256 timeStaked, uint256 pid) internal view returns (uint256) {
        StakingTier memory tierInfo = tiers[pid];     
        uint256 rewardPerSecond = _getRewardPerSecond(amount, tierInfo); 
        uint256 totalRewards = amount + (rewardPerSecond * timeStaked); 

        if (tierInfo.stakingDuration == 0) return totalRewards; 
        
        //get the amount of round trips the user has completed 
        //round trip = times completed the stakingTime to earn a bonus
        //a stakingTime of 1 day would mean that for every complete day spent staking == 1 round trip
        uint256 daysStaked = timeStaked / 1 days; 
        uint256 roundTrips = daysStaked / (tierInfo.stakingDuration / 1 days); //for bonus payouts 
        if (roundTrips == 0) return totalRewards; 

        //for initial trip
        uint256 finalAmount = amount + _getRewardPerSecond(amount, tierInfo) * tierInfo.stakingDuration; 
        //uint256 finalAmount = totalRewards; 

        for (uint256 i = 0; i < roundTrips;) {
            finalAmount += (finalAmount * tierInfo.bonus / DENOMINATOR); 

            if (roundTrips == 1) break; 

            uint256 newRps = _getRewardPerSecond(finalAmount, tierInfo) * tierInfo.stakingDuration; 
            finalAmount += newRps; 

            unchecked { i++; }
        }

        uint256 leftoverSeconds = timeStaked - (daysStaked * 1 days); 
        finalAmount += _getRewardPerSecond(finalAmount, tierInfo) * leftoverSeconds;  
        
        return finalAmount; 
    }

    function _getRewardPerSecond(uint256 amount, StakingTier memory tierInfo) internal pure returns (uint256) {
        uint256 rewardPerSecond = amount * tierInfo.apy / YEAR / DENOMINATOR;  
        return rewardPerSecond; 
    }

    function getUnderlyingAmounts(uint256 amount) internal view returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(degenatorLP);
        address token0 = pair.token0(); 

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        uint256 totalLP = pair.totalSupply();

        uint256 userDegenatorAmount = token0 == address(degenator) ? (amount * reserve0) / totalLP : (amount * reserve1) / totalLP; 
        return userDegenatorAmount;     
    }

    function earned(address user, uint256 pid) external view returns (uint256) {
        return multiplyStakingBalance(user, pid); 
    }
}
