// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MoaiFactory.sol";

contract DeployMoai is Script {
    function run() external {

        // USDC address
    
        address usdc = vm.envAddress("USDC_ADDRESS");

        // Moai parameters
        string memory name = "Friends Moai";
        uint256 contributionAmount = 100 * 1e6; // 100 USDC (6 decimals)
        uint256 cycleDayDue = 5;                 // Day 5 of 30-day cycle
        uint256 removalThresholdMonths = 2;

        // =============================
        // DEPLOY
        // =============================

        vm.startBroadcast();

        // 1. Deploy Factory
        MoaiFactory factory = new MoaiFactory(usdc);

        // 2. Create Moai via Factory
        address moaiAddress = factory.createMoai(
            name,
            contributionAmount,
            cycleDayDue,
            removalThresholdMonths,
            msg.sender
        );

        vm.stopBroadcast();

        // =============================
        // LOG OUTPUT
        // =============================

        console.log("MoaiFactory deployed at:", address(factory));
        console.log("Moai deployed at:", moaiAddress);
        console.log("Deployer:", msg.sender);
    }
}
