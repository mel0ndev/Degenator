// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

contract Degenator is ERC20, Owned {
    uint256 public TAX_AMOUNT = 5;
    uint256 public TAX_POT_MAX = 500_000e18;

    uint256 public MAX_TX_AMOUNT = 10_000_000e18; 

    mapping(address => bool) internal whitelist; 

    IUniswapV2Factory immutable uniswapFactory;
    IUniswapV2Router02 immutable uniswapRouter;
    address internal immutable WETH; 

    address public tokenPair;
    address public stakingContract;
    address public legendaryStakingContract; 
    address internal teamWallet;

    bool public tradingPaused = false;
    //@dev bool to control taxing during trasfers for dex swaps
    bool public isTaxOn = false;
    bool internal inSwapEvent = false; 

    error TaxTooHigh();
    error AboveMaximumTxnAmount(); 
    error TradingIsPaused(); 

    event TaxAmountChanged(uint256 newTaxAmount);
    event TradingPaused(bool, uint256 block);
    event Tax(address indexed sender, uint256 taxAmount);
    event MaxPotChanged(uint256 newPotMax);
    event MaxTxnAmountChanged(uint256 newTxnAmount); 
    event ToggleTax(bool);
    event ChangePayout(address indexed newWallet);
    event Whitelisted(address indexed user); 

    modifier onlyStaking() virtual {
        require(msg.sender == stakingContract || msg.sender == legendaryStakingContract, "UNAUTHORIZED");
        _;
    }

    modifier swapEvent() {
      inSwapEvent = true; 
      _; 
      inSwapEvent = false; 
    }

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
    }

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

    function changeMaxTxn(uint256 newTxnAmount) external onlyOwner {
        MAX_TX_AMOUNT = newTxnAmount; 
        emit MaxTxnAmountChanged(newTxnAmount); 
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

    function _transfer(address from, address to, uint256 amount) public returns (bool) {
        if (tradingPaused) revert TradingIsPaused(); 
         
        if (!whitelist[from]) {
            if (amount > MAX_TX_AMOUNT) revert AboveMaximumTxnAmount(); 
        }
        
        if (balanceOf[address(this)] >= TAX_POT_MAX && 
            isTaxOn && 
            from != tokenPair &&
            !inSwapEvent) {
            _swapAndPayOut();
        }

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        if (from == owner || from == address(this) || from == stakingContract) {
            unchecked {
                balanceOf[to] += amount;
            }
        } else {
            unchecked {
                balanceOf[to] += amount - _addTax(amount);
                balanceOf[address(this)] += _addTax(amount);
            }
        }

        emit Transfer(from, to, amount - _addTax(amount));
        emit Tax(from, _addTax(amount));
        
        return true;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
      bool success = _transfer(msg.sender, to, amount); 
      return success; 
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        bool success = _transfer(from, to, amount); 
        return success; 
    }
}
