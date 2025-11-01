// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.30;

/**
 * @author  atharva-potdar
 * @title   Raffle Smart Contract
 * @dev     Uses ChainLink VRF v2.5 for randomizations
 * @notice  This contract is for creating a simple raffle
 */

contract Raffle {
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

    /**
     * State Variables
     */

    // @dev Entrance fee for the raffle
    uint256 private immutable I_ENTRANCE_FEE;

    // @dev Duration of the raffle in seconds
    uint256 private immutable I_RAFFLE_DURATION;

    // @dev Minimum number of players required to pick a winner
    uint256 private immutable I_MINIMUM_PLAYERS;

    // @dev Raffle pool amount
    uint256 private sRafflePool;

    // @dev Mapping of a player to their number of tickets
    mapping(address => uint256) private sPlayers;

    // @dev List of players weighted according to their tickets
    address[] private sWeightedPlayersList;

    /**
     * Events
     */

    // @dev Emitted when a player enters the raffle
    event RaffleEntered(address indexed player, uint256 tickets);

    /**
     * Functions
     */

    constructor(uint256 entranceFee, uint256 raffleDuration, uint256 minimumPlayers) {
        I_ENTRANCE_FEE = entranceFee;
        I_RAFFLE_DURATION = raffleDuration;
        I_MINIMUM_PLAYERS = minimumPlayers;
    }

    // @dev Function to enter the raffle
    function enterRaffle() external payable {
        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle__NotEnoughMoneyToEnterRaffle();
        }

        uint256 raffleTickets = msg.value / I_ENTRANCE_FEE;

        sRafflePool += msg.value;
        sPlayers[msg.sender] += raffleTickets;
        for (uint256 i = 0; i < raffleTickets;) {
            sWeightedPlayersList.push(msg.sender);
            unchecked {
                ++i;
            }
        }
        emit RaffleEntered(msg.sender, raffleTickets);
    }

    // @dev Function to pick a winner
    function pickWinner() external {
        if (sWeightedPlayersList.length < I_MINIMUM_PLAYERS) {
            revert Raffle__NotEnoughPlayersToPickWinner();
        }
        if (block.timestamp % I_RAFFLE_DURATION != 0) {
            revert Raffle__RaffleDurationNotMet();
        }
    }

    /**
     * Getter functions
     */

    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }

    function getRafflePool() external view returns (uint256) {
        return sRafflePool;
    }

    function getNumberOfTickets(address player) external view returns (uint256) {
        return sPlayers[player];
    }
}
