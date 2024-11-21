// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Degenator} from "src/Degenator.sol";
import {DegenStaking} from "src/DegenStaking.sol"; 
import {LegendaryDegenStaking} from "src/LegendaryDegenStaking.sol"; 
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol";


contract EndToEndTest is Test {

    address lp; 
    Degenator degenator; 
    DegenStaking staking; 
    LegendaryDegenStaking legendaryStaking; 

    address immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IUniswapV2Router02 immutable uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory immutable uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f); 

    address alice = address(69); 

    function setUp() public {
        // precompute all addresses 
        address computedStaking = vm.computeCreateAddress(address(this), 2); 
        address computedLegendary = vm.computeCreateAddress(address(this), 3); 

        // deploy degenator
        degenator = new Degenator(
            computedStaking, 
            computedLegendary, 
            address(this),
            address(uniswapFactory), 
            address(uniswapRouter),
            WETH, 
            "Bozo",
            "BOZO"
        );

        //deploy staking
        staking = new DegenStaking(degenator); 
        
        // get the lp address 
        lp = uniswapFactory.getPair(address(degenator), WETH); 

        //deploy legendary staking
        legendaryStaking = new LegendaryDegenStaking(degenator, lp, address(uniswapRouter), WETH); 

        uint256 degenatorBalance = degenator.balanceOf(address(this)); 
        assertEq(degenatorBalance, 1_000_000_000e18); 

        //whitelist this address
        degenator.addWhitelist(address(this)); 
    }

    function testEndToEndFlowRegularStaking() public {
        //we start with WETH
        //
        //add some liquidity to the uniswap v2 pool 
        //1) deal some weth
        deal(WETH, address(this), 15e18); 
        uint256 degenatorBalance = degenator.balanceOf(address(this)); 

        //approve
        degenator.approve(address(uniswapRouter), type(uint256).max); 
        IERC20(WETH).approve(address(uniswapRouter), type(uint256).max); 

        //add the liquidity (this would be joel)
        uniswapRouter.addLiquidity(
            address(degenator), 
            WETH,
            degenatorBalance,
            15e18, 
            0, 
            0, 
            address(this), 
            block.timestamp + 5
        ); 
        
        //now, simulate users buying the token
        //give alice some weth and approve
        deal(WETH, alice, 0.05e18); 
        vm.prank(alice); 
        IERC20(WETH).approve(address(uniswapRouter), type(uint256).max); 
        
        //set up our swap path
        address[] memory path = new address[](2);  
        path[0] = WETH; 
        path[1] = address(degenator); 

        //alice buys some DGN
        vm.prank(alice); 
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            0.05e18, 
            0, 
            path, 
            alice, 
            block.timestamp + 1
        ); 
        
        //check that alice's buy went through
        assertGt(degenator.balanceOf(alice), 0); 

        //check that tax was taken on buy
        assertGt(degenator.balanceOf(address(degenator)), 0); 
        
        uint256 aliceBalance = degenator.balanceOf(alice); 

        //now alice can stake her DGN, she chooses max tier 
        vm.prank(alice);  
        staking.stake(aliceBalance, 4); 
        
        //we go a week into the future and check rewards 
        skip(1 weeks); 
        
        uint256 aliceEarned0 = staking.earned(alice, 4); 
        assertGt(aliceEarned0, 0); 
        //our second week to apply boost
        skip(1 weeks); 

        uint256 aliceEarned1 = staking.earned(alice, 4); 
        assertGt(aliceEarned1, aliceEarned0);  
    
        //now alice wants to unstake     
        vm.startPrank(alice); 
        vm.expectRevert(); 
        staking.claim(4); 

        staking.unstake(4); 

        vm.stopPrank(); 
        
        (, , uint256 stakeEnd)  = staking.stakingBalances(alice, 4); 
        assertEq(stakeEnd, block.timestamp); 
        
        //try to claim without waiting the full unstake period
        vm.startPrank(alice); 
        vm.expectRevert(); 
        staking.claim(4);
        
        //wait a bit but not the full time    
        skip(30 hours);  

        vm.expectRevert(); 
        staking.claim(4);

        skip(18 hours); 
        staking.claim(4);
        vm.stopPrank(); 
        
        aliceBalance = degenator.balanceOf(alice);  
        assertGt(aliceBalance, 0); 
        
        vm.startPrank(alice); 
        degenator.approve(address(uniswapRouter), aliceBalance); 
        //now she wants to sell her tokens
        path[0] = address(degenator);  
        path[1] = WETH; 
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            aliceBalance,
            0, 
            path, 
            alice, 
            block.timestamp + 1
        ); 

        vm.stopPrank(); 
        
        uint256 aliceWETH = IERC20(WETH).balanceOf(alice); 
        assertGt(aliceWETH, 0); 
    }

    function testEndToEndFlowLegendaryStaking() public {
        //we start with WETH
        //
        //add some liquidity to the uniswap v2 pool 
        //1) deal some weth
        deal(WETH, address(this), 15e18); 
        uint256 degenatorBalance = degenator.balanceOf(address(this)); 

        //approve
        degenator.approve(address(uniswapRouter), type(uint256).max); 
        IERC20(WETH).approve(address(uniswapRouter), type(uint256).max); 

        //add the liquidity (this would be joel)
        uniswapRouter.addLiquidity(
            address(degenator), 
            WETH,
            degenatorBalance,
            15e18, 
            0, 
            0, 
            address(this), 
            block.timestamp + 5
        ); 
        
        //now, simulate users buying the token
        //give alice some weth and approve
        deal(WETH, alice, 0.05e18); 
        vm.prank(alice); 
        IERC20(WETH).approve(address(uniswapRouter), type(uint256).max); 
        
        //set up our swap path
        address[] memory path = new address[](2);  
        path[0] = WETH; 
        path[1] = address(degenator); 

        //alice buys some DGN
        vm.prank(alice); 
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            0.05e18, 
            0, 
            path, 
            alice, 
            block.timestamp + 1
        ); 
        
        //check that alice's buy went through
        assertGt(degenator.balanceOf(alice), 0); 

        //check that tax was taken on buy
        assertGt(degenator.balanceOf(address(degenator)), 0); 
        
        uint256 aliceBalance = degenator.balanceOf(alice); 

        console.log("DEGENATOR BALANCE", aliceBalance); 

        //now alice can add liquidity herself
        deal(WETH, alice, 0.05e18); 
        vm.startPrank(alice);  
        degenator.approve(address(uniswapRouter), type(uint256).max); 
        IERC20(lp).approve(address(legendaryStaking), type(uint256).max); 
        uniswapRouter.addLiquidity(
            address(degenator), 
            WETH,
            aliceBalance,
            0.05e18, 
            0, 
            0, 
            alice, 
            block.timestamp + 1
        ); 

        uint256 aliceLpBalance = IERC20(lp).balanceOf(alice); 

        console.log("LP BALANCE:", aliceLpBalance); 
        legendaryStaking.stake(aliceLpBalance, 0); 
        vm.stopPrank(); 
        
        //we go a week into the future and check rewards 
        skip(1 weeks); 
        
        uint256 aliceEarned0 = legendaryStaking.earned(alice, 0); 
        assertGt(aliceEarned0, 0); 
        ////our second week to apply boost
        //skip(1 weeks); 

        //uint256 aliceEarned1 = staking.earned(alice, 4); 
        //assertGt(aliceEarned1, aliceEarned0);  
    
        ////now alice wants to unstake     
        //vm.startPrank(alice); 
        //vm.expectRevert(); 
        //staking.claim(4); 

        //staking.unstake(4); 

        //vm.stopPrank(); 
        //
        //(, , uint256 stakeEnd)  = staking.stakingBalances(alice, 4); 
        //assertEq(stakeEnd, block.timestamp); 
        //
        ////try to claim without waiting the full unstake period
        //vm.startPrank(alice); 
        //vm.expectRevert(); 
        //staking.claim(4);
        //
        ////wait a bit but not the full time    
        //skip(30 hours);  

        //vm.expectRevert(); 
        //staking.claim(4);

        //skip(18 hours); 
        //staking.claim(4);
        //vm.stopPrank(); 
        //
        //aliceBalance = degenator.balanceOf(alice);  
        //assertGt(aliceBalance, 0); 
        //
        //vm.startPrank(alice); 
        //degenator.approve(address(uniswapRouter), aliceBalance); 
        ////now she wants to sell her tokens
        //path[0] = address(degenator);  
        //path[1] = WETH; 
        //uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        //    aliceBalance,
        //    0, 
        //    path, 
        //    alice, 
        //    block.timestamp + 1
        //); 

        //vm.stopPrank(); 
        //
        //uint256 aliceWETH = IERC20(WETH).balanceOf(alice); 
        //assertGt(aliceWETH, 0); 
    }
}
