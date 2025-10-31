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

    uint256 private immutable I_ENTRANCE_FEE;

    constructor(uint256 entranceFee) {
        I_ENTRANCE_FEE = entranceFee;
    }

    function enterRaffle() public {}

    function pickWinner() public {}

    /**
     * Getter functions
     */

    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }
}
