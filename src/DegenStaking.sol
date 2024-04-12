// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.0;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Degenator} from "./Degenator.sol";

//TODO remove
import {Test, console2} from "forge-std/Test.sol";


contract DegenStaking is Owned, Test {
    using SafeTransferLib for ERC20;

    Degenator public degenator;

    struct StakingBalance {
        uint256 deposited;
        uint256 stakeStart;
        uint256 stakeEnd;
    }

    struct StakingTier {
        uint256 stakingDuration; 
        uint256 apy;
        uint256 bonus; 
        uint256 unstakeDuration; 
    }

    uint256 internal constant DENOMINATOR = 1e19; 

    mapping(address user => mapping(uint256 pid => StakingBalance)) public stakingBalances; //user can have a per pid staking balance
    mapping(uint256 pid => StakingTier) public tiers; 

    event Staked(address indexed staker, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed staker, uint256 timestamp);
    event Claim(address indexed staker, uint256 amount, uint256 timestamp);

    error ZeroAmount();
	error PeriodNotFinished(); 
	error PeriodStillActive(); 
	error PeriodAlreadyStarted(); 

    constructor(Degenator _degenator) Owned(msg.sender) {
        degenator = _degenator; 

        //initialize staking tiers
        //pleb tier
        tiers[0] = StakingTier({
            stakingDuration: 0, 
            apy: 1e18, //10%
            bonus: 0,  
            unstakeDuration: 4 hours
        }); 
        
        //rookie
        tiers[1] = StakingTier({
            stakingDuration: 1 days, 
            apy: 200, //20%
            bonus: 10, //1% 
            unstakeDuration: 12 hours
        }); 
        
        //chad 
        tiers[2] = StakingTier({
            stakingDuration: 3 days, 
            apy: 300, //30%
            bonus: 90, //9% 
            unstakeDuration: 24 hours
        }); 
        
        //patron
        tiers[3] = StakingTier({
            stakingDuration: 7 days, 
            apy: 700, //70%
            bonus: 420, //42% 
            unstakeDuration: 36 hours
        }); 

        //degenator
        tiers[4] = StakingTier({
            stakingDuration: 14 days, 
            apy: 1400, //140%
            bonus: 1680, //168% 
            unstakeDuration: 48 hours
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
		

        ERC20(address(degenator)).safeTransferFrom(msg.sender, address(this), amount);
        //account for tax
        amount -= (amount * degenator.TAX_AMOUNT()) / 100;
        stakingBalances[msg.sender][pid].deposited += amount;

        //redepositing more will reset your staking time, this is desired behavior
        stakingBalances[msg.sender][pid].stakeStart = block.timestamp;
        stakingBalances[msg.sender][pid].stakeEnd = 0;

        emit Staked(msg.sender, amount, block.timestamp);
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

        uint256 amountToWithdraw = multiplyStakingBalance(msg.sender, pid);

        //burn the user's deposit since we are minting new coins
        degenator.burn(address(this), user.deposited);

        user.deposited = 0;
        user.stakeStart = 0;
        user.stakeEnd = 0;

        //mint the entire amount on unstake
        degenator.mint(msg.sender, amountToWithdraw);

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

        //uint256 daysStaked = timeStaked / 1 days;
        uint256 hoursStaked = timeStaked / 1 hours;

        console2.log("hours staked", hoursStaked); 
        
        uint256 a = _getWithdrawAmount(startingBalance, timeStaked, pid); 
        return a; 
    }
    
    /**
     * @notice gets the amount to be withdrawn for the user based on their tier and staking time
     * @param amount - the initial staking deposit amount of the user
     * @param timeStaked - the time spend staked in the pool
     * @param pid - the pool id (tier) we're calculating returns for
     * @return the total amount to be withdrawn, inclusive of initial deposit amount
     */ 
    function _getWithdrawAmount(uint256 amount, uint256 timeStaked, uint256 pid) internal view returns (uint256) {
        StakingTier memory tierInfo = tiers[pid];     
        uint256 rewardPerSecond = amount * tierInfo.apy / 365 / 24 / 60 / 60 / DENOMINATOR;  

        uint256 totalRewards = amount + (rewardPerSecond * timeStaked); 
        console2.log(totalRewards); 
        if (tierInfo.stakingDuration == 0) {
            return totalRewards; 
        }

        //get the amount of round trips the user has completed 
        //round trip = times completed the stakingTime to earn a bonus
        //a stakingTime of 1 day would mean that for every complete day spent staking == 1 round trip
        uint256 hoursStaked = timeStaked / 1 hours;
        uint256 roundTrips = hoursStaked / tierInfo.stakingDuration; //for bonus payouts 
        console2.log(roundTrips); 

        //uint256 bonusTokens = 
    }
}
