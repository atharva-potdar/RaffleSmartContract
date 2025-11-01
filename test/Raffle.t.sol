// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";

contract RaffleTest is Test {
    Raffle private raffle;
    uint256 private constant ENTRANCE_FEE = 0.001 ether;
    uint256 private constant RAFFLE_DURATION = 7 days;
    uint256 private constant MINIMUM_PLAYERS = 5;
    address private immutable player = makeAddr("ificouldsmokefearaway");

    function setUp() public {
        raffle = new Raffle(ENTRANCE_FEE, RAFFLE_DURATION, MINIMUM_PLAYERS);
    }

    function testGetEntranceFee() public view {
        assertEq(raffle.getEntranceFee(), ENTRANCE_FEE);
    }

    function testEnterRevertsIfNotEnoughEth() public {
        vm.expectRevert();
        raffle.enterRaffle{value: ENTRANCE_FEE - 1}();
    }

    function testGetRafflePool() public {
        raffle.enterRaffle{value: ENTRANCE_FEE * 3}();
        assertEq(raffle.getRafflePool(), ENTRANCE_FEE * 3);
    }

    function testGetNumberOfTickets() public {
        vm.deal(player, ENTRANCE_FEE * 5);
        vm.prank(player);
        raffle.enterRaffle{value: ENTRANCE_FEE * 5}();
        assertEq(raffle.getNumberOfTickets(player), 5);
    }

    /**
     *  Relevant functions:
     *  function enterRaffle() public payable {
     *      if (msg.value < I_ENTRANCE_FEE) {
     *          revert Raffle__NotEnoughMoneyToEnterRaffle();
     *      }
     *  }
     *
     *  function enterRaffle2() public payable {
     *      require(msg.value >= I_ENTRANCE_FEE, Raffle__NotEnoughMoneyToEnterRaffle());
     *  }
     *
     *  Test Gas Report
     *  RaffleTest:testEnterRaffle2RevertsIfNotEnoughEth() (gas: 15157)
     *  RaffleTest:testEnterRevertsIfNotEnoughEth() (gas: 15134)
     *  RaffleTest:testGetEntranceFee() (gas: 5755)
     *
     *  Conclusion: Using require with custom errors is slightly more gas expensive
     *  than using revert with custom errors.
     */
}
