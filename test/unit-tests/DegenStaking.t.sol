// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Degenator} from "src/Degenator.sol";
import {DegenStaking} from "src/DegenStaking.sol"; 
import {LegendaryDegenStaking} from "src/LegendaryDegenStaking.sol"; 
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol"; 


contract DegenStakingTest is Test {
    Degenator degenator;
    DegenStaking staking;
    LegendaryDegenStaking legendaryStaking; 
    address internal lp; 

    address bob = address(69);
    address alice = address(420);
    address charlie = address(42069);

    address immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IUniswapV2Router02 immutable uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory immutable uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f); 


    address owner;

    function setUp() public {
        address computedStaking = vm.computeCreateAddress(address(this), 2); 
        address computedLegendary = vm.computeCreateAddress(address(this), 3); 
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
        staking = new DegenStaking(degenator); 
        
        lp = uniswapFactory.getPair(address(degenator), WETH); 

        legendaryStaking = new LegendaryDegenStaking(degenator, lp, address(uniswapRouter), WETH); 
        owner = degenator.owner();
        deal(address(degenator), alice, 500_000_000e18);
    }

    function testTiersSetup() public view {
        //pleb
        (uint256 stakingDuration, uint256 apy, uint256 bonus, uint256 unstakeDuration) = staking.tiers(0);  

        assertEq(stakingDuration, 0); 
        assertEq(apy, 1e18); 
        assertEq(bonus, 0); 
        assertEq(unstakeDuration, 4 hours); 

        (stakingDuration, apy, bonus, unstakeDuration) = staking.tiers(1);  

        assertEq(stakingDuration, 1 days); 
        assertEq(apy, 2e18); 
        assertEq(bonus, 1e16); 
        assertEq(unstakeDuration, 12 hours); 
        
        //chad
        (stakingDuration, apy, bonus, unstakeDuration) = staking.tiers(2);  

        assertEq(stakingDuration, 3 days); 
        assertEq(apy, 3e18); 
        assertEq(bonus, 9e17); 
        assertEq(unstakeDuration, 24 hours); 
        
        //patron
        (stakingDuration, apy, bonus, unstakeDuration) = staking.tiers(3);  

        assertEq(stakingDuration, 7 days); 
        assertEq(apy, 7e18); 
        assertEq(bonus, 42e17); 
        assertEq(unstakeDuration, 36 hours); 
        
        //degenator
        (stakingDuration, apy, bonus, unstakeDuration) = staking.tiers(4);  

        assertEq(stakingDuration, 14 days); 
        assertEq(apy, 14e18); 
        assertEq(bonus, 168e17); 
        assertEq(unstakeDuration, 48 hours); 
    }

    function testStakePleb(uint96 amount) public {
        vm.assume(amount > 1e18); 
        vm.assume(amount <= degenator.balanceOf(alice)); 

        vm.prank(alice); 
        staking.stake(amount, 0);  
        
        (uint256 deposited, uint256 startTime, uint256 endTime) = staking.stakingBalances(alice, 0); 

        assertEq(deposited, amount - (amount * degenator.TAX_AMOUNT()) / 100); 
        assertEq(startTime, block.timestamp); 
        assertEq(endTime, 0); 

        (deposited, startTime, endTime) = staking.stakingBalances(alice, 1); 
        assertEq(deposited, 0); 
        assertEq(startTime, 0); 
        assertEq(endTime, 0); 
    }

    function testUnstakePleb() public {
        testStakePleb(100e18); 
        
        skip(1 days * 365); 
        
        vm.prank(alice); 
        staking.unstake(0); 
        (, , uint256 endTime) = staking.stakingBalances(alice, 0); 
        assertEq(endTime, block.timestamp); 
    }

    function testClaimPleb() public {
        testUnstakePleb(); 

        skip(4 hours); 

        vm.prank(alice); 
        uint256 returned = staking.claim(0); 
        console2.log("amount returned", returned); 
    }

    function testStakeRookie(uint96 amount) public {
        vm.assume(amount > 1e18); 
        vm.assume(amount <= degenator.balanceOf(alice)); 

        vm.prank(alice); 
        staking.stake(amount, 1);  
        
        (uint256 deposited, uint256 startTime, uint256 endTime) = staking.stakingBalances(alice, 1); 

        assertEq(deposited, amount - (amount * degenator.TAX_AMOUNT()) / 100); 
        assertEq(startTime, block.timestamp); 
        assertEq(endTime, 0); 

        (deposited, startTime, endTime) = staking.stakingBalances(alice, 2); 
        assertEq(deposited, 0); 
        assertEq(startTime, 0); 
        assertEq(endTime, 0); 
    }

    function testUnstakeRookie() public {
        testStakeRookie(100_000e18); 
        
        skip(5 days + 35 minutes + 24 seconds); 
        
        vm.prank(alice); 
        staking.unstake(1); 
        (, , uint256 endTime) = staking.stakingBalances(alice, 1); 
        assertEq(endTime, block.timestamp); 
    }

    function testClaimRookie() public {
        testUnstakeRookie(); 

        skip(12 hours); 

        vm.prank(alice); 
        uint256 returned = staking.claim(1); 
        console2.log("amount returned", returned); 
    }

    function testUnstakeChad() public {
        _stakeTier(100e18, 2); 
        
        skip(3 days); 
        
        vm.prank(alice); 
        staking.unstake(2); 
        (, , uint256 endTime) = staking.stakingBalances(alice, 2); 
        assertEq(endTime, block.timestamp); 
    }

    function testClaimChad() public {
        testUnstakeChad(); 
        
        skip(24 hours); 

        vm.prank(alice); 
        uint256 returned = staking.claim(2); 
        console2.log("amount returned", returned); 
    }

    function testUnstakePatron() public {
        _stakeTier(100e18, 3); 
        
        skip(7 days); 
        
        vm.prank(alice); 
        staking.unstake(3); 
        (, , uint256 endTime) = staking.stakingBalances(alice, 3); 
        assertEq(endTime, block.timestamp); 
    }

    function testClaimPatron() public {
        testUnstakePatron(); 
        
        skip(36 hours); 

        vm.prank(alice); 
        uint256 returned = staking.claim(3); 
        console2.log("amount returned", returned); 
    }

    function testUnstakeDegenator() public {
        _stakeTier(100e18, 4); 
        
        skip(14 days); 
        
        vm.prank(alice); 
        staking.unstake(4); 
        (, , uint256 endTime) = staking.stakingBalances(alice, 4); 
        assertEq(endTime, block.timestamp); 
    }

    function testClaimDegenator() public {
        testUnstakeDegenator(); 
        
        skip(48 hours); 

        vm.prank(alice); 
        uint256 returned = staking.claim(4); 
        console2.log("amount returned", returned); 
    }

    function _stakeTier(uint256 amount, uint256 tier) internal {
        vm.prank(alice); 
        staking.stake(amount, tier);  
    }

    function testStakeLp() public {
        deal(lp, alice, 10e18); 
        uint256 balance = IERC20(lp).balanceOf(alice); 
            
        vm.startPrank(alice); 
        IERC20(lp).approve(address(legendaryStaking), type(uint256).max); 
        legendaryStaking.stake(balance, 0); 
        vm.stopPrank(); 

        (uint256 deposited, uint256 lpAmount, uint256 startTime, uint256 endTime) = legendaryStaking.stakingBalances(alice, 0); 

        console2.log("LP deposited", lpAmount); 
        
        uint256 balanceOfStakingContract = IERC20(lp).balanceOf(address(legendaryStaking)); 
        console2.log("STAKING CONTRACT BALANCE", balanceOfStakingContract); 

        assertEq(deposited, balance); 
        assertEq(startTime, block.timestamp); 
        assertEq(endTime, 0); 
    }

    function testUnstakeLp() public {
        testStakeLp(); 

        skip(30 days); 
        
        vm.prank(alice); 
        legendaryStaking.unstake(0); 
        (, , , uint256 endTime) = legendaryStaking.stakingBalances(alice, 0); 
        assertEq(endTime, block.timestamp); 
    }

    function testClaimLp() public {
        testUnstakeLp(); 

        skip(60 hours); 

        vm.prank(alice); 
        uint256 returned = legendaryStaking.claim(0); 
        console2.log("amount returned", returned); 
    } 

}
