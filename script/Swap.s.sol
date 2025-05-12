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

    address internal constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; 
    address internal constant DEGENATOR = 0x1016a221e3E9Dd994ac3cee091c0B7437EeB6800; 
    address internal constant RECEIVER = 0xDC91F82F64Ef2159B63Fb64fC99Ad20725084fcB;  
    IUniswapV2Factory immutable uniswapFactory = IUniswapV2Factory(0xF62c03E08ada871A0bEb309762E260a7a6a880E6); 
    IUniswapV2Router02 immutable uniswapRouter = IUniswapV2Router02(0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3);

    //LegendaryMasterchef masterchef = LegendaryMasterchef(0x06a9ABC288D0568C78f621f92fF629486413B225); 

    function run() public {
        vm.startBroadcast(vm.envUint("SWAP_KEY")); 

        IWETH(WETH).deposit{value: 0.005e18}(); 
            
        IERC20(DEGENATOR).approve(address(uniswapRouter), type(uint256).max); 
        IERC20(WETH).approve(address(uniswapRouter), type(uint256).max); 

        //require(IERC20(WETH).balanceOf(RECEIVER) == 0.2e18); 
        //require(IERC20(DEGENATOR).balanceOf(RECEIVER) >= 100_000e18); 

        address[] memory path = new address[](2);  
        path[0] = WETH; 
        path[1] = DEGENATOR; 

        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            0.005e18,
            0,
            path,
            RECEIVER,
            block.timestamp + 100
        );
    }
}
