// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.30;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @author  atharva-potdar
 * @title   Raffle Smart Contract
 * @dev     Uses ChainLink VRF v2.5 for randomizations
 * @notice  This contract is for creating a simple raffle
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /*
        The two main functions that our smart contract will revolve around are:
        Entering the raffle and then picking the winner. Everything else will
        be built around these.
    */

    /**
     * Errors
     */

    error Raffle__NotEnoughMoneyToEnterRaffle();
    error Raffle__RaffleDurationNotMet();
    error Raffle__NotEnoughPlayersToPickWinner();
    error Raffle__TransferFailed();

    /**
     * Type Declarations
     */

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**
     * State Variables
     */

    // @dev ChainLink VRF variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint8 private constant NUM_WORDS = 1;
    bool private constant ENABLE_NATIVE_PAYMENT = false; // false -> LINK payment, true -> native token paymen t
    uint32 private immutable I_CALLBACK_GAS_LIMIT;
    bytes32 private immutable I_KEY_HASH;
    uint256 private immutable I_SUBSCRIPTION_ID;

    // @dev Entrance fee for the raffle
    uint256 private immutable I_ENTRANCE_FEE;

    // @dev Duration of the raffle in seconds
    uint256 private immutable I_RAFFLE_DURATION;

    // @dev Minimum number of players required to pick a winner
    uint256 private immutable I_MINIMUM_PLAYERS;

    // @dev Mapping of a player to their number of tickets
    mapping(address => uint256) private sPlayers;

    // @dev List of unique players in the raffle
    address[] private sUniquePlayersList;

    // @dev Mapping of a player to existence in the raffle list
    mapping(address => bool) private sIsPlayerInList;

    // @dev Total number of tickets in the raffle
    uint256 private sTotalTickets;

    // @dev Raffle start time
    uint256 private sRaffleStartTime;

    // @dev Recent winner address
    address private sRecentWinner;

    // @dev Store the current state of the raffle
    RaffleState private sRaffleState;

    /**
     * Events
     */

    // @dev Emitted when a player enters the raffle
    event RaffleEntered(address indexed player, uint256 tickets);

    /**
     * Functions
     */

    constructor(
        uint256 entranceFee,
        uint256 raffleDuration,
        uint256 minimumPlayers,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_ENTRANCE_FEE = entranceFee;
        I_RAFFLE_DURATION = raffleDuration;
        I_MINIMUM_PLAYERS = minimumPlayers;
        sRaffleStartTime = block.timestamp;
        I_KEY_HASH = keyHash;
        I_SUBSCRIPTION_ID = subscriptionId;
        I_CALLBACK_GAS_LIMIT = callbackGasLimit;
        sRaffleState = RaffleState.OPEN;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        address payable winner = payable(sUniquePlayersList[randomWords[0] % sUniquePlayersList.length]);
        sRecentWinner = winner;
        (bool success,) = winner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    // @dev Function to enter the raffle
    function enterRaffle() external payable {
        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle__NotEnoughMoneyToEnterRaffle();
        }

        uint256 raffleTickets = msg.value / I_ENTRANCE_FEE;

        sPlayers[msg.sender] += raffleTickets;
        sTotalTickets += raffleTickets;

        if (!sIsPlayerInList[msg.sender]) {
            sUniquePlayersList.push(msg.sender);
            sIsPlayerInList[msg.sender] = true;
        }

        emit RaffleEntered(msg.sender, raffleTickets);
    }

    // @dev Function to pick a winner
    function pickWinner() external returns (address) {
        uint256 totalRaffleTickets = sTotalTickets;

        if (totalRaffleTickets < I_MINIMUM_PLAYERS) {
            revert Raffle__NotEnoughPlayersToPickWinner();
        }
        if (block.timestamp - sRaffleStartTime < I_RAFFLE_DURATION) {
            revert Raffle__RaffleDurationNotMet();
        }

        // Taken from ChainLink VRF v2.5 docs
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: I_KEY_HASH, // Gas lane that the oracle uses for this request
                subId: I_SUBSCRIPTION_ID, // Subscription ID that this contract uses
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: I_CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: ENABLE_NATIVE_PAYMENT})
                )
            })
        );

        uint256 randomNumber = 3; // Placeholder for ChainLink VRF random number
        address[] memory playersList = sUniquePlayersList;
        uint256 sPlayersLength = playersList.length;
        uint256 cumulativeTickets = 0;

        for (uint256 i = 0; i < sPlayersLength;) {
            address currentPlayer = playersList[i];
            uint256 playerTickets = sPlayers[currentPlayer];
            if (randomNumber < cumulativeTickets + playerTickets) {
                // Found the winner
                // Transfer the raffle pool to the winner
                return currentPlayer;
            }
            unchecked {
                i++;
            }
            cumulativeTickets += playerTickets;
        }
    }

    /**
     * Getter functions
     */

    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }

    function getRafflePool() external view returns (uint256) {
        return address(this).balance;
    }

    function getNumberOfTickets(address player) external view returns (uint256) {
        return sPlayers[player];
    }

    function getMinimumPlayers() external view returns (uint256) {
        return I_MINIMUM_PLAYERS;
    }

    function getRaffleDuration() external view returns (uint256) {
        return I_RAFFLE_DURATION;
    }

    function getRaffleStartTime() external view returns (uint256) {
        return sRaffleStartTime;
    }

    function getTotalTickets() external view returns (uint256) {
        return sTotalTickets;
    }
}
