// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Degenator} from "src/Degenator.sol"; 
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol"; 
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol"; 

interface IWETH {
    function deposit() external payable;  
}

contract Deploy is Script {

//    address internal constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; 
//    address internal constant DEGENATOR = 0xab1c127Bd97A50AB188EC20D21adeb286573b7F2; 
//    address internal constant RECEIVER = 0x097cF877320845ff3dc6ae7916b913843cC11a50; 
//    IUniswapV2Factory immutable uniswapFactory = IUniswapV2Factory(0x7E0987E5b3a30e3f2828572Bb659A548460a3003); 
//    IUniswapV2Router02 immutable uniswapRouter = IUniswapV2Router02(0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008);
//
//    //LegendaryMasterchef masterchef = LegendaryMasterchef(0x06a9ABC288D0568C78f621f92fF629486413B225); 
//
//    function run() public {
//        vm.startBroadcast(vm.envUint("PRIVATE_KEY")); 
//
//        IWETH(WETH).deposit{value: 0.01e18}(); 
//            
//        IERC20(DEGENATOR).approve(address(uniswapRouter), type(uint256).max); 
//        IERC20(WETH).approve(address(uniswapRouter), type(uint256).max); 
//
//        //require(IERC20(WETH).balanceOf(RECEIVER) == 0.2e18); 
//        //require(IERC20(BOZO).balanceOf(RECEIVER) >= 100_000e18); 
//
//        uniswapRouter.addLiquidity(
//            WETH,
//            DEGENATOR,
//            0.01e18,
//            1000e18,
//            100,
//            100,
//            RECEIVER,
//            block.timestamp + 30
//        );
//
//        //masterchef.add(1e17, IERC20(0xCB8E4FE80F43321031D46d58e7B4220f5d0DfeBf), false); 
//
//        //address[] memory path = new address[](2);
//        //path[0] = WETH;
//        //path[1] = BOZO;
//        //
//        ////swap WETH to BOZO  
//        //uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
//        //    balanceOf[address(this)], 0, path, teamWallet, block.timestamp
//        //);
//    }

}
