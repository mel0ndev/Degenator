// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ClockStaking} from "./ClockStaking.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";

contract Degenator is ERC20, Owned {
    uint256 public TAX_AMOUNT = 10;
    uint256 public TAX_POT_MAX = 500_000e18;
    uint256 public MAX_TRANSFER_AMOUNT = 1_000_000_000e18 * 2 / 10; //TODO: come back to this

    IUniswapV2Factory immutable uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniswapV2Router02 immutable uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    //testnet
    //IUniswapV2Factory immutable uniswapFactory = IUniswapV2Factory(0x7E0987E5b3a30e3f2828572Bb659A548460a3003);
    //IUniswapV2Router02 immutable uniswapRouter = IUniswapV2Router02(0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008);

    address immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    //sepolia weth
    //address immutable WETH = 0xf531B8F309Be94191af87605CfBf600D71C2cFe0;

    address public tokenPair;
    address public stakingContract;
    address internal teamWallet;

    bool public tradingPaused = false;
    bool public whaleProtectionPeriod = false;
    //@dev bool to control taxing during trasfers for dex swaps
    bool public isTaxOn = false;

    error TaxTooHigh();
    error WhaleProtectionActive();

    event TaxAmountChanged(uint256 newTaxAmount);
    event TradingPaused(bool, uint256 block);
    event Tax(address indexed sender, uint256 taxAmount);
    event MaxPotChanged(uint256 newPotMax);
    event ToggleTax(bool);
    event ChangePayout(address indexed newWallet);

    modifier onlyStaking() virtual {
        require(msg.sender == stakingContract, "UNAUTHORIZED");

        _;
    }

    constructor(address _stakingContract, address _teamWallet) ERC20("Degenator", "DGN", 18) Owned(msg.sender) {
        _mint(owner, 1_000_000_000e18);
        stakingContract = _stakingContract;
        teamWallet = _teamWallet;
        tokenPair = uniswapFactory.createPair(address(this), WETH);
    }
    
    //TODO come back to this
    function initialize() external onlyOwner {
        IERC20(address(this)).approve(address(uniswapRouter), type(uint256).max);
        isTaxOn = true;
        whaleProtectionPeriod = true;
    }

    function mint(address to, uint256 amount) external onlyStaking {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyStaking {
        _burn(from, amount);
    }

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

    function toggleTax(bool value) external onlyOwner {
        isTaxOn = value;
        emit ToggleTax(value);
    }
    
    //TODO come back to this
    function toggleWhaleProtection(bool value) external onlyOwner {
        whaleProtectionPeriod = value;
    }

    function setTeamWallet(address wallet) external onlyOwner {
        teamWallet = wallet;
        emit ChangePayout(wallet);
    }

    //@dev in case something goes wrong and we end up with a different liquidity token address(this shouldn't happen but just in case)
    function updateTokenPair(address newTokenPair) external onlyOwner {
        tokenPair = newTokenPair;
    }

    function updateStakingContract(address newStakingContract) external onlyOwner {
        stakingContract = newStakingContract;
    }

    function _addTax(uint256 amount) internal view returns (uint256) {
        return (amount * TAX_AMOUNT) / 100;
    }
    
    //TODO come back to this and fix, UniswapV2 callback issue 
    function _swapAndPayOut() internal {
        //avoids weird recursion loop
        isTaxOn = false;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        //we don't care about slippage here since there might be very low liquidity, and
        //we still want the sale to succeed no matter what
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            balanceOf[address(this)], 0, path, teamWallet, block.timestamp
        );

        //tax back on after swap
        isTaxOn = true;
    }
    
    //TODO fix this as well
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        if (whaleProtectionPeriod == true && amount >= MAX_TRANSFER_AMOUNT) {
            revert WhaleProtectionActive();
        }

        if (balanceOf[address(this)] >= TAX_POT_MAX && isTaxOn) {
            _swapAndPayOut();
        }

        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        if (msg.sender == owner || msg.sender == address(this) || msg.sender == stakingContract) {
            unchecked {
                balanceOf[to] += amount;
            }
        } else {
            unchecked {
                balanceOf[to] += amount - _addTax(amount);
                balanceOf[address(this)] += _addTax(amount);
            }
        }

        emit Transfer(msg.sender, to, amount - _addTax(amount));
        emit Tax(msg.sender, _addTax(amount));

        return true;
    }
    
    //TODO: fix this as well
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        if (whaleProtectionPeriod == true && amount >= MAX_TRANSFER_AMOUNT) {
            revert WhaleProtectionActive();
        }

        if (balanceOf[address(this)] >= TAX_POT_MAX && isTaxOn) {
            _swapAndPayOut();
        }
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

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
}
