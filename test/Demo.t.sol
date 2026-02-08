// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Moai} from "../src/Moai.sol";
import {MoaiFactory} from "../src/MoaiFactory.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/**
 * @title Full protocol demo (run in ~30 seconds with time warp)
 * @notice Run: forge test --match-test test_FullProtocolDemo -vvv
 * @dev Uses vm.warp() to simulate months passing - no contract changes needed for production.
 */
contract DemoTest is Test {
    Moai public moai;
    MoaiFactory public factory;
    MockUSDC public usdc;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xC4101);

    uint256 constant CONTRIBUTION = 100 * 1e6; // 100 USDC
    uint256 constant CYCLE_DAY_DUE = 5;
    uint256 constant REMOVAL_THRESHOLD = 2;

    function _warpToDistribution() internal {
        vm.warp(moai.getNextDistributionDate());
    }

    function _contributeAll() internal {
        address[] memory m = moai.getMembers();
        for (uint256 i = 0; i < m.length; i++) {
            vm.startPrank(m[i]);
            usdc.approve(address(moai), CONTRIBUTION);
            moai.contribute();
            vm.stopPrank();
        }
    }

    function test_FullProtocolDemo() public {
        console.log("========================================");
        console.log("  MOAI PROTOCOL - 5 MINUTE DEMO");
        console.log("========================================");

        // ---- 1. DEPLOY ----
        console.log("\n--- 1. DEPLOY ---");
        usdc = new MockUSDC();
        usdc.mint(alice, 1_000_000 * 1e6);
        usdc.mint(bob, 1_000_000 * 1e6);
        usdc.mint(carol, 1_000_000 * 1e6);

        factory = new MoaiFactory(address(usdc));
        vm.prank(alice);
        address moaiAddr = factory.createMoai(
            "Demo Savings Circle",
            CONTRIBUTION,
            CYCLE_DAY_DUE,
            REMOVAL_THRESHOLD,
            alice
        );
        moai = Moai(payable(moaiAddr));
        console.log("Factory deployed, Moai created. Members: 1 (alice)");

        // ---- 2. MEMBERS JOIN ----
        console.log("\n--- 2. MEMBERS JOIN ---");
        vm.prank(bob);
        moai.joinMoai();
        vm.prank(carol);
        moai.joinMoai();
        console.log("Bob and Carol joined. Total members: 3");

        // ---- 3. MONTH 1: EVERYONE CONTRIBUTES ----
        console.log("\n--- 3. MONTH 1: CONTRIBUTIONS ---");
        _contributeAll();
        console.log("All 3 paid 100 USDC. Pool balance:", moai.getTotalBalance() / 1e6, "USDC");

        // ---- 4. DISTRIBUTE (after due date + 1 day) ----
        console.log("\n--- 4. DISTRIBUTE MONTH 1 ---");
        _warpToDistribution();
        moai.distributeMonth();
        console.log("Distributed: 70% to round-robin recipient, 30% to emergency reserve.");
        console.log("Next round-robin recipient index advanced. Emergency reserve:", moai.getEmergencyReserve() / 1e6, "USDC");

        // ---- 5. WITHDRAW ROUND-ROBIN (whoever got it) ----
        console.log("\n--- 5. WITHDRAW ROUND-ROBIN ---");
        uint256 pending = moai.getPendingDistribution(alice);
        if (pending > 0) {
            vm.prank(alice);
            moai.withdraw();
            console.log("Alice withdrew her round-robin share.");
        }

        // ---- 6. MONTH 2: CAROL DOESN'T PAY (outstanding) ----
        console.log("\n--- 6. MONTH 2: CAROL SKIPS PAYMENT ---");
        vm.startPrank(alice);
        usdc.approve(address(moai), CONTRIBUTION);
        moai.contribute();
        vm.stopPrank();
        vm.startPrank(bob);
        usdc.approve(address(moai), CONTRIBUTION);
        moai.contribute();
        vm.stopPrank();
        _warpToDistribution();
        moai.distributeMonth();
        console.log("Carol's outstanding:", moai.getOutstanding(carol) / 1e6, "USDC");

        // ---- 7. (Pay outstanding would go here - we skip so Carol has 2 months outstanding for removal demo) ----
        console.log("\n--- 7. (Members can call payOutstanding(amount) to catch up; we skip so removal is possible) ---");

        // ---- 8. EMERGENCY REQUEST ----
        console.log("\n--- 8. EMERGENCY REQUEST ---");
        uint256 maxEmergency = (moai.emergencyReserve() * 15) / 100;
        vm.prank(alice);
        uint256 reqId = moai.requestEmergency(maxEmergency);
        vm.prank(alice);
        moai.voteEmergency(reqId, true);
        vm.prank(bob);
        moai.voteEmergency(reqId, true);
        console.log("Alice requested emergency. Alice + Bob voted -> Approved (51%+).");
        vm.prank(alice);
        moai.withdraw();
        console.log("Alice withdrew emergency amount.");

        // ---- 9. MONTH 3: CAROL SKIPS AGAIN -> REMOVAL ELIGIBLE ----
        console.log("\n--- 9. MONTH 3: REMOVAL FLOW ---");
        vm.startPrank(alice);
        usdc.approve(address(moai), CONTRIBUTION);
        moai.contribute();
        vm.stopPrank();
        vm.startPrank(bob);
        usdc.approve(address(moai), CONTRIBUTION);
        moai.contribute();
        vm.stopPrank();
        _warpToDistribution();
        moai.distributeMonth();
        assertTrue(moai.canBeRemoved(carol));
        vm.prank(alice);
        uint256 removalId = moai.proposeRemoval(carol);
        vm.prank(alice);
        moai.voteRemoval(removalId, true);
        vm.prank(bob);
        moai.voteRemoval(removalId, true);
        console.log("Carol exceeded 2 months outstanding. Proposed removal, 51% voted -> Carol removed.");
        console.log("Members now: 2 (alice, bob)");

        // ---- 10. DISSOLUTION (unanimous) ----
        console.log("\n--- 10. DISSOLUTION ---");
        vm.prank(alice);
        moai.voteForDissolution();
        vm.prank(bob);
        moai.voteForDissolution();
        console.log("Alice and Bob voted for dissolution. Unanimous -> Moai dissolved.");
        uint256 share = moai.dissolutionSharePerMember();
        vm.prank(alice);
        moai.withdraw();
        vm.prank(bob);
        moai.withdraw();
        console.log("Each withdrew equal share:", share / 1e6, "USDC");

        console.log("\n========================================");
        console.log("  DEMO COMPLETE - ALL FLOWS SHOWN");
        console.log("========================================");
    }
}
