// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    // TODO: Write tests for this script if needed
    function run() public {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        // Create VRF Subscription
        (uint256 subId,) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address) {
        console.log("Creating subscription on VRF Coordinator: %d with Chain ID: ", vrfCoordinator, block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Subscription created with ID: ", subId);
        console.log("Please update the subscriptionId in the HelperConfig contract!");
        return (subId, vrfCoordinator);
    }
}

contract FundSubscription is Script {
    uint256 constant FUND_AMOUNT = 5 ether;

    // TODO: Write tests for this script if needed
    function run() public {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId; // updated before this
        address linkToken = helperConfig.getConfig().linkToken;

        fundSubscription(vrfCoordinator, subscriptionId, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
        console.log(
            "Funding subscription %d on VRF Coordinator: %d with Chain ID: %d",
            subscriptionId,
            vrfCoordinator,
            block.chainid
        );

        if (block.chainid == 31337) {
            // Anvil - fund via direct method
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            // For testnets/mainnet, use LINK token to fund
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }

        console.log("Subscription funded with %d LINK", FUND_AMOUNT);
    }
}

contract AddConsumer is Script {
    // TODO: Write tests for this script if needed
    function addConsumerUsingConfig(address contractToAddToVrf) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId; // updated before this

        addConsumer(contractToAddToVrf, vrfCoordinator, subscriptionId);
    }

    function run() public {
        address contractToAddToVrf = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(contractToAddToVrf);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subscriptionId) public {
        console.log("Adding consumer contract %d to VRF Subscription %d", contractToAddToVrf, subscriptionId);
        console.log("On VRF Coordinator: %d with Chain ID: %d", vrfCoordinator, block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, contractToAddToVrf);
        vm.stopBroadcast();
    }
}
