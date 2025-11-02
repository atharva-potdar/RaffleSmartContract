// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 raffleDuration;
        uint256 minimumPlayers;
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address linkToken;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;
    uint256 private constant ENTRANCE_FEE = 0.01 ether;
    uint256 private constant RAFFLE_DURATION = 30 seconds;
    uint256 private constant MINIMUM_PLAYERS = 3;
    uint32 private constant CALLBACK_GAS_LIMIT = 500000;
    uint256 private constant SUBSCRIPTION_ID = 0;

    constructor() {
        networkConfigs[11155111] = getSepoliaEthConfig();
        networkConfigs[421614] = getSepoliaArbitrumConfig();
        networkConfigs[31337] = getOrCreateAnvilConfig();
        uint256 chainId = block.chainid;
        activeNetworkConfig = networkConfigs[chainId];
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            raffleDuration: RAFFLE_DURATION,
            minimumPlayers: MINIMUM_PLAYERS,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            subscriptionId: SUBSCRIPTION_ID,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getSepoliaArbitrumConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            raffleDuration: RAFFLE_DURATION,
            minimumPlayers: MINIMUM_PLAYERS,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            subscriptionId: SUBSCRIPTION_ID,
            vrfCoordinator: 0x5CE8D5A2BC84beb22a398CCA51996F7930313D61,
            keyHash: 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be,
            linkToken: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
            0.25 ether, // Base fee
            1e9, // Gas price link
            4e15 // Wei per unit link
        );

        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();

        activeNetworkConfig = NetworkConfig({
            entranceFee: ENTRANCE_FEE,
            raffleDuration: RAFFLE_DURATION,
            minimumPlayers: MINIMUM_PLAYERS,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            subscriptionId: 0,
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            keyHash: 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15, // value doesn't matter
            linkToken: address(linkToken)
        });

        return activeNetworkConfig;
    }
}
