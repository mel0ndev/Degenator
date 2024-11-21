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

    address internal constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; 
    IUniswapV2Factory immutable uniswapFactory = IUniswapV2Factory(0x7E0987E5b3a30e3f2828572Bb659A548460a3003); 
    IUniswapV2Router02 immutable uniswapRouter = IUniswapV2Router02(0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008);

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


}
