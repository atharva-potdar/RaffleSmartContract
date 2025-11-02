// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public returns (Raffle, HelperConfig) {
        (Raffle raffle, HelperConfig helperConfig) = deployContract();
        return (raffle, helperConfig);
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        if (networkConfig.subscriptionId == 0) {
            // Create VRF Subscription
            CreateSubscription subscriptionCreator = new CreateSubscription();
            (networkConfig.subscriptionId, networkConfig.vrfCoordinator) =
                subscriptionCreator.createSubscription(networkConfig.vrfCoordinator);

            FundSubscription funder = new FundSubscription();
            funder.fundSubscription(networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.linkToken);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.raffleDuration,
            networkConfig.minimumPlayers,
            networkConfig.vrfCoordinator,
            networkConfig.keyHash,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();

        // no need to broadcast since it's already in addConsumer function
        addConsumer.addConsumer(address(raffle), networkConfig.vrfCoordinator, networkConfig.subscriptionId);

        return (raffle, helperConfig);
    }
}
