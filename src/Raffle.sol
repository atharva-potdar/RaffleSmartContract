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


    /**
     * State Variables
     */
    uint256 private immutable I_ENTRANCE_FEE;
    uint256 private sRafflePool;
    mapping(address => uint256) private sPlayers; // address => number of tickets

    /**
     * Events
     */
    event RaffleEntered(address indexed player, uint256 tickets);

    constructor(uint256 entranceFee) {
        I_ENTRANCE_FEE = entranceFee;
    }

    function enterRaffle() public payable {
        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle__NotEnoughMoneyToEnterRaffle();
        }

        uint256 raffleTickets = msg.value / I_ENTRANCE_FEE;

        sRafflePool += msg.value;
        sPlayers[msg.sender] = raffleTickets;
        emit RaffleEntered(msg.sender, raffleTickets);
    }

    // function pickWinner() public {}

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
