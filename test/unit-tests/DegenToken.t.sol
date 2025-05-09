// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Degenator} from "src/Degenator.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol";

contract DegenatorTest is Test {
    Degenator degenator;

    address bob = address(69);
    address alice = address(420);
    address charlie = address(42069);

    address immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IUniswapV2Router02 immutable uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory immutable uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f); 

    address owner;

    function setUp() public {
        degenator = new Degenator(
            address(1), 
            address(2), 
            address(this),
            address(uniswapFactory), 
            address(uniswapRouter),
            WETH, 
            "Bozo",
            "BOZO"
        );
        deal(WETH, address(this), 1e18);
        owner = degenator.owner();
        deal(address(degenator), alice, 500_000_000e18);

        IERC20(WETH).approve(address(degenator), type(uint256).max);
        degenator.initialize(); 
        initializeLiquidity();
    }

    function initializeLiquidity() internal {
        uint256 amountADesired = 50_000_000e18;
        uint256 amountBDesired = 1e18;

        IERC20(address(degenator)).approve(address(uniswapRouter), type(uint256).max);
        IERC20(WETH).approve(address(uniswapRouter), type(uint256).max);

        //IERC20(WETH).transferFrom(msg.sender, address(this), amountBDesired);

        uniswapRouter.addLiquidity(
            address(degenator),
            WETH,
            amountADesired,
            amountBDesired,
            amountADesired - amountADesired / 100,
            amountBDesired - amountBDesired / 100,
            owner,
            block.timestamp
        );
    }

   // function swapExactTokensForTokensSupportingFeeOnTransferTokens(
   //   uint amountIn,
   //   uint amountOutMin,
   //   address[] calldata path,
   //   address to,
   //   uint deadline
   //) external;
    
    function testTransfer() external {
        degenator.changeMaxWalletAmount(type(uint256).max - 1); 
        deal(address(degenator), address(this), 100e18); 
        uint256 balance420 = degenator.balanceOf(address(420)); 
        console2.log(balance420); 
        degenator.transfer(address(420), 100e18);     
        balance420 = degenator.balanceOf(address(420)); 
        console2.log(balance420); 
    }

    function testTransferFrom() external {
        degenator.changeMaxWalletAmount(type(uint256).max - 1); 
        deal(address(degenator), bob, 100e18); 

        uint256 balance420 = degenator.balanceOf(bob); 
        console2.log(balance420); 

        vm.prank(bob); 
          degenator.approve(alice, type(uint256).max); 

        vm.prank(alice); 
          degenator.transferFrom(bob, alice, 100e18); 

        balance420 = degenator.balanceOf(address(420)); 
        console2.log(balance420); 
    }

    function testUniswapV2SwapDGNToWETH() external {
      address[] memory path = new address[](2); 
      path[0] = address(degenator); 
      path[1] = WETH; 

      uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        1000e18,
        0,
        path,
        address(this),
        block.timestamp
      );
      
      uint256 balanceDegenAfterSwap = IERC20(address(degenator)).balanceOf(address(this)); 
      uint256 balanceWethAfterSwap = IERC20(WETH).balanceOf(address(this)); 
      console2.log("Balance DGN After Swap:", balanceDegenAfterSwap); 
      console2.log("Balance WETH After Swap:", balanceWethAfterSwap); 

    }

    function testUniswapV2SwapWETHToDGN() external {
      address[] memory path = new address[](2); 
      path[0] = WETH; 
      path[1] = address(degenator); 

      deal(WETH, address(this), 0.1e18); 

      uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        0.1e18,
        0,
        path,
        address(this),
        block.timestamp
      );
      
      uint256 balanceDegenAfterSwap = IERC20(address(degenator)).balanceOf(address(this)); 
      uint256 balanceWethAfterSwap = IERC20(WETH).balanceOf(address(this)); 
      console2.log("Balance DGN After Swap:", balanceDegenAfterSwap); 
      console2.log("Balance WETH After Swap:", balanceWethAfterSwap); 
    }

    function testUniswapV2SwapWETHToDGNFullPot() external {
      deal(address(degenator), address(degenator), 550_000e18); 
      console2.log("HERE"); 

      address[] memory path = new address[](2); 
      path[0] = WETH; 
      path[1] = address(degenator); 

      deal(WETH, address(this), 0.1e18); 

      uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        0.1e18,
        0,
        path,
        address(this),
        block.timestamp
      );
      
      uint256 balanceDegenAfterSwap = IERC20(address(degenator)).balanceOf(address(this)); 
      uint256 balanceWethAfterSwap = IERC20(WETH).balanceOf(address(this)); 
      console2.log("Balance DGN After Swap:", balanceDegenAfterSwap); 
      console2.log("Balance WETH After Swap:", balanceWethAfterSwap); 
      //assertGt(balanceWethAfterSwap, 0); 
    }

    function testUniswapV2SwapDGNToWETHFullPot() external {
      deal(address(degenator), address(degenator), 550_000e18); 

      address[] memory path = new address[](2); 
      path[0] = address(degenator); 
      path[1] = WETH; 

      deal(address(degenator), address(this), 500e18); 

      uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        500e18,
        0,
        path,
        address(this),
        block.timestamp
      );
      
      uint256 balanceDegenAfterSwap = IERC20(address(degenator)).balanceOf(address(this)); 
      uint256 balanceWethAfterSwap = IERC20(WETH).balanceOf(address(this)); 
      console2.log("Balance DGN After Swap:", balanceDegenAfterSwap); 
      console2.log("Balance WETH After Swap:", balanceWethAfterSwap); 
      //assertGt(balanceWethAfterSwap, 0); 
    }

    function testTax(uint96 amount) external {
        uint256 tax = degenator.TAX_AMOUNT();
        uint256 taxAmount = (amount * tax) / 100;
        console2.log(taxAmount);

        assertEq(taxAmount, (amount * tax) / 100);
    }

    function testChangeTaxAmount() external {
        vm.prank(degenator.owner());
        degenator.changeTaxAmount(50);
        uint256 tax = degenator.TAX_AMOUNT();
        uint256 taxAmount = (1e18 * tax) / 100;

        assertEq(taxAmount, 5e17);
    }

    function testChangePotMax() external {
        vm.prank(degenator.owner());
        degenator.changeMaxPot(50e18);

        assertEq(degenator.TAX_POT_MAX(), 50e18);
    }

    //function testWhaleProtection(uint96 amount) external {
    //    uint256 aliceBalance = degenator.balanceOf(alice);
    //    uint256 tax = degenator.TAX_AMOUNT();
    //    assertEq(degenator.whaleProtectionPeriod(), true);
    //    vm.assume(amount <= aliceBalance);

    //    if (amount >= 1_000_000_000e18 * 2 / 10) {
    //        vm.prank(alice);
    //        vm.expectRevert();
    //        IERC20(address(degenator)).transfer(bob, amount);
    //    } else {
    //        vm.prank(alice);
    //        IERC20(address(degenator)).transfer(bob, amount);
    //    }
    //}

    //function testWhaleProtectionFail() external {
    //    vm.prank(alice);
    //    vm.expectRevert();
    //    IERC20(address(degenator)).transfer(bob, 300_000_000e18);
    //}

    //function testWhaleProtectionPass() external {
    //    degenator.toggleWhaleProtection(false);
    //    deal(address(degenator), alice, 500_000_000e18); 
    //    vm.prank(alice);
    //    IERC20(address(degenator)).transfer(bob, 300_000_000e18);
    //}

    //no way to tax amounts under 10, but users are losing money to gas, so it's not profitable for them to do so
    function testTransfer(uint96 amount) external {
        degenator.changeMaxWalletAmount(type(uint256).max - 1); 
        uint256 aliceBalance = degenator.balanceOf(alice);
        uint256 tax = degenator.TAX_AMOUNT();
        deal(address(degenator), alice, amount);
        vm.assume(amount <= aliceBalance);
        uint256 degenatorBalanceBefore = degenator.balanceOf(address(degenator));

        vm.prank(alice);
        degenator.transfer(bob, amount);

        uint256 degenatorBalanceAfter = degenator.balanceOf(address(degenator));
        uint256 bobBalance = degenator.balanceOf(bob);
        console2.log(bobBalance);
        assertEq(bobBalance, amount - ((amount * tax) / 100));
        assertEq(degenatorBalanceAfter, degenatorBalanceBefore + (amount * tax) / 100);
    }

    function testTransferTax() external {
        uint256 aliceBalance = degenator.balanceOf(alice);
        uint256 tax = degenator.TAX_AMOUNT();
        deal(address(degenator), alice, 100_000e18);
        uint256 degenatorBalanceBefore = degenator.balanceOf(address(degenator));
        console2.log("balance before", degenatorBalanceBefore);

        vm.prank(alice);
        degenator.transfer(bob, 100_000e18);

        uint256 degenatorBalanceAfter = degenator.balanceOf(address(degenator));
        uint256 bobBalance = degenator.balanceOf(bob);
        console2.log(bobBalance);
        console2.log("balance after", degenatorBalanceAfter);
    }

    function testBreakTransfer() external {
        deal(address(degenator), alice, 100e18);

        vm.prank(alice);
        vm.expectRevert();
        degenator.transfer(bob, 110e18);
    }

    function testTransferFrom(uint96 amount) external {
        degenator.changeMaxWalletAmount(type(uint256).max - 1); 
        uint256 contractBal = degenator.balanceOf(address(this));
        vm.prank(degenator.owner());

        vm.assume(amount <= contractBal);
        uint256 degenatorBalanceBefore = degenator.balanceOf(address(degenator));

        deal(address(degenator), bob, amount);

        vm.startPrank(bob);
        degenator.approve(bob, amount);
        degenator.transferFrom(bob, charlie, amount);
        vm.stopPrank();

        uint256 tax = degenator.TAX_AMOUNT();

        uint256 degenatorBalanceAfter = degenator.balanceOf(address(degenator));
        uint256 charlieBalance = degenator.balanceOf(charlie);
        assertEq(charlieBalance, amount - ((amount * tax) / 100));
        assertEq(degenatorBalanceAfter, degenatorBalanceBefore + (amount * tax) / 100);
    }

    function testPauseTrading() external {
        degenator.pauseTrading(true);
        assertEq(degenator.tradingPaused(), true);

        degenator.pauseTrading(false);
        assertEq(degenator.tradingPaused(), false);
    }

    function testPayoutToWallet() public {
        assertEq(IERC20(address(degenator)).balanceOf(address(degenator)), 0);

        deal(address(degenator), address(degenator), 200_000_000e18);
        console2.log("balance in contract", degenator.balanceOf(address(degenator)));
        console2.log("approval amount", degenator.allowance(address(degenator), address(uniswapRouter)));

        degenator.transfer(bob, 1e18);

        uint256 profits = IERC20(WETH).balanceOf(degenator.owner());
        console2.log(profits);
    }

    function testPayoutToWalletFromTransfers() public {
        uint256 aliceBalance = degenator.balanceOf(alice);
        uint256 tax = degenator.TAX_AMOUNT();
        deal(address(degenator), alice, 1_000_000e18);
        uint256 degenatorBalanceBefore = degenator.balanceOf(address(degenator));
        console2.log("balance before", degenatorBalanceBefore);

        vm.prank(alice);
        degenator.transfer(bob, 1_000_000e18);

        uint256 degenatorBalanceAfter = degenator.balanceOf(address(degenator));
        uint256 bobBalance = degenator.balanceOf(bob);
        console2.log(bobBalance);
        console2.log("balance after", degenatorBalanceAfter);

        degenator.transfer(alice, 1e18);

        uint256 profits = IERC20(WETH).balanceOf(degenator.owner());
        console2.log(profits);
    }

    function testSendToSelf() public {
        degenator.changeMaxWalletAmount(type(uint256).max - 1); 

        uint256 aliceBalance = degenator.balanceOf(alice);
        console2.log("BALANCE START", aliceBalance); 
        vm.startPrank(alice); 
        degenator.transfer(alice, aliceBalance); 
        uint256 tax = degenator.TAX_AMOUNT();
        console2.log("TAX AMOUNT", tax); 
        uint256 aliceBalanceAfter = degenator.balanceOf(alice);

        assertEq(aliceBalanceAfter, aliceBalance - (aliceBalance * tax) / 100); 
        console2.log("BALANCE END", aliceBalanceAfter); 
    }
}
