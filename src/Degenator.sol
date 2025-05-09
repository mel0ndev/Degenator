// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

contract Degenator is ERC20, Owned {

    /// @notice tax amount
    uint256 public TAX_AMOUNT = 5;

    uint256 public TAX_POT_MAX = 500_000e18;
    
    /// @notice max amount that can be transfered
    uint256 public MAX_TX_AMOUNT = 10_000_000e18; 

    /// @notice max amount that can be held by any wallet
    uint256 public MAX_HOLD_AMOUNT = 10_000_000e18; 
    
    /// @notice list of whitelsited addresses to not be taxed (staking contracts, etc)
    mapping(address => bool) internal whitelist; 
    
    /// @notice uniswap addresses
    IUniswapV2Factory immutable uniswapFactory;
    IUniswapV2Router02 immutable uniswapRouter;
    address internal immutable WETH; 
    
    /// @notice lp staking pair
    address public tokenPair;

    /// @notice token staking contract address 
    address public stakingContract;

    /// @notice legendary token staking contract address 
    address public legendaryStakingContract; 

    address internal teamWallet;

    bool public tradingPaused = false;

    bool public whitelistOn = true; 

    //@dev bool to control taxing during trasfers for dex swaps
    bool public isTaxOn = false;
    //@dev flag for if we are in a swap or not
    bool internal inSwapEvent = false; 
    

    /////////////////////////////// ERRORS ///////////////////////////////
    
    error TaxTooHigh();
    error TradingIsPaused(); 
    error MaxWalletAmount(); 

    /////////////////////////////// EVENTS ///////////////////////////////

    event TaxAmountChanged(uint256 newTaxAmount);
    event TradingPaused(bool, uint256 block);
    event Tax(address indexed sender, uint256 taxAmount);
    event MaxPotChanged(uint256 newPotMax);
    event MaxWalletAmountChanged(uint256 newAmount); 
    event ToggleTax(bool);
    event ChangePayout(address indexed newWallet);
    event Whitelisted(address indexed user); 
    event Unwhitelisted(address indexed user); 

    /////////////////////////////// MODIFIERS ///////////////////////////////
    
    modifier onlyStaking() virtual {
        require(msg.sender == stakingContract || msg.sender == legendaryStakingContract, "UNAUTHORIZED");
        _;
    }

    modifier swapEvent() {
      inSwapEvent = true; 
      _; 
      inSwapEvent = false; 
    }

    /////////////////////////////// CONSTRUCTOR ///////////////////////////////
    
    constructor(
        address _stakingContract, 
        address _legendaryStakingContract, 
        address _teamWallet, 
        address _factory,
        address _router,
        address _weth,
        string memory _name, 
        string memory _symbol) 
    ERC20(_name, _symbol, 18) Owned(msg.sender) {
        _mint(owner, 1_000_000_000e18);

        stakingContract = _stakingContract;
        legendaryStakingContract = _legendaryStakingContract; 
        teamWallet = _teamWallet;

        uniswapFactory = IUniswapV2Factory(_factory); 
        uniswapRouter = IUniswapV2Router02(_router); 
        WETH = _weth; 

        tokenPair = uniswapFactory.createPair(address(this), WETH);

        whitelist[teamWallet] = true; 
        whitelist[tokenPair] = true; 
        whitelist[stakingContract] = true; 
        whitelist[legendaryStakingContract] = true; 
    }

    /////////////////////////////// PERMISSIONED FUNCTIONS ///////////////////////////////

    function initialize() external onlyOwner {
        IERC20(address(this)).approve(address(uniswapRouter), type(uint256).max);
        isTaxOn = true;
    }
    
    //@param to -- tokens to be minted to this address
    //@param amount -- amount of tokens to be minted
    function mint(address to, uint256 amount) external onlyStaking {
        _mint(to, amount);
    }
    
    //@param from -- tokens burned from this address
    //@param amount -- amount of tokens to be burned from 'from' address
    function burn(address from, uint256 amount) external onlyStaking {
        _burn(from, amount);
    }
    
    //@param pause -- pause or reinstate trading
    function pauseTrading(bool pause) external onlyOwner {
        tradingPaused = pause;
        emit TradingPaused(pause, block.timestamp);
    }

    function changeTaxAmount(uint256 newTaxAmount) external onlyOwner {
        if (newTaxAmount > 99) {
            revert TaxTooHigh();
        }
        TAX_AMOUNT = newTaxAmount;
        emit TaxAmountChanged(newTaxAmount);
    }

    function changeMaxPot(uint256 newPotMax) external onlyOwner {
        TAX_POT_MAX = newPotMax;
        emit MaxPotChanged(newPotMax);
    }

    function changeMaxWalletAmount(uint256 newAmount) external onlyOwner {
        MAX_HOLD_AMOUNT = newAmount; 
        emit MaxWalletAmountChanged(newAmount); 
    }

    function toggleTax(bool value) external onlyOwner {
        isTaxOn = value;
        emit ToggleTax(value);
    }

    function setTeamWallet(address wallet) external onlyOwner {
        teamWallet = wallet;
        emit ChangePayout(wallet);
    }

    function addWhitelist(address user) external onlyOwner {
        whitelist[user] = true; 
        emit Whitelisted(user); 
    }

    function removeWhitelist(address user) external onlyOwner {
        whitelist[user] = false; 
        emit Unwhitelisted(user); 
    }

    //@dev in case something goes wrong and we end up with a different liquidity token address(this shouldn't happen but just in case)
    function updateTokenPair(address newTokenPair) external onlyOwner {
        tokenPair = newTokenPair;
    }

    function updateStakingContract(address newStakingContract) external onlyOwner {
        stakingContract = newStakingContract;
    }

    function updateLegendaryStakingContract(address newLegendaryStaking) external onlyOwner {
        legendaryStakingContract = newLegendaryStaking; 
    }

    function toggleWhitelist(bool onOrOff) external onlyOwner {
        whitelistOn = onOrOff; 
    }

    /////////////////////////////// INTERNAL FUNCTIONS ///////////////////////////////
    
    function _addTax(uint256 amount) internal view returns (uint256) {
        return (amount * TAX_AMOUNT) / 100;
    }

    function _swapAndPayOut() internal swapEvent {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;
        
        //we don't care about slippage here
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            balanceOf[address(this)], 0, path, teamWallet, block.timestamp
        );
    }
    
    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        if (tradingPaused) revert TradingIsPaused(); 
         
        //if (!whitelist[from]) {
        //    if (amount > MAX_TX_AMOUNT) revert MaxWalletAmount(); 
        //}
        
        if (balanceOf[address(this)] >= TAX_POT_MAX && 
            isTaxOn && 
            from != tokenPair &&
            !inSwapEvent) {
            _swapAndPayOut();
        }

        uint256 taxAmount = 0; 
        if (!(from == owner || from == address(this) || from == stakingContract || from == legendaryStakingContract)) {
            taxAmount = _addTax(amount);
        }

        uint256 transferAmount = amount - taxAmount;
        
        if (!whitelist[to]) {
            if (balanceOf[to] + transferAmount > MAX_HOLD_AMOUNT) revert MaxWalletAmount(); 
        }

        balanceOf[from] -= amount;
        balanceOf[to] += transferAmount;

        if (taxAmount > 0) {
            balanceOf[address(this)] += taxAmount;
        }

        emit Transfer(from, to, transferAmount);
        if (taxAmount > 0) {
            emit Tax(from, taxAmount);
        }
        
        return true;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
      bool success = _transfer(msg.sender, to, amount); 
      return success; 
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        bool success = _transfer(from, to, amount); 
        return success; 
    }
}
