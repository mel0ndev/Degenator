// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol"; 
import {Script, console2} from "forge-std/Script.sol";
import {Degenator} from "src/Degenator.sol"; 
import {DegenStaking} from "src/DegenStaking.sol"; 
import {LegendaryDegenStaking} from "src/LegendaryDegenStaking.sol"; 
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol"; 
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol"; 

interface IWETH {
    function deposit() external payable;  
}

contract Deploy is Script {

    //mainnet
    //address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    //IUniswapV2Factory immutable uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f); 
    
    //sepolia  
//    address internal constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; 
//    IUniswapV2Factory immutable uniswapFactory = IUniswapV2Factory(0x7E0987E5b3a30e3f2828572Bb659A548460a3003); 
//    IUniswapV2Router02 immutable uniswapRouter = IUniswapV2Router02(0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008);
//    address internal constant RECEIVER = 0x097cF877320845ff3dc6ae7916b913843cC11a50; 
//
//    address payoutWallet = 0x097cF877320845ff3dc6ae7916b913843cC11a50; 
//    address shitcoinDeployer = 0x097cF877320845ff3dc6ae7916b913843cC11a50; 
//
//    function run() public {
//        vm.startBroadcast(vm.envUint("PRIVATE_KEY")); 
//
//        uint256 nonce = vm.getNonce(shitcoinDeployer);
//        address degenStakingAddress = vm.computeCreateAddress(shitcoinDeployer, nonce + 1);
//        address legendaryMasterchef = vm.computeCreateAddress(shitcoinDeployer, nonce + 2);
//        Degenator degenator = new Degenator(degenStakingAddress, legendaryMasterchef, payoutWallet);
//        DegenStaking staking = new DegenStaking(degenator); 
//
//        //init degenator token, not done during testing
//        degenator.initialize(); 
//
//        IWETH(WETH).deposit{value: 0.05e18}(); 
//       
//        degenator.approve(address(uniswapRouter), type(uint256).max); 
//        IERC20(WETH).approve(address(uniswapRouter), type(uint256).max); 
//
//        
//        console2.log("TOKEN", address(degenator));  
//        console2.log("LP ADDRESS", degenator.tokenPair());  
//        console2.log("STAKING", address(staking)); 
//    }
}
