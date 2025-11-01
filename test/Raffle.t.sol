// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";

contract RaffleTest is Test {
    Raffle private raffle;
    uint256 private constant ENTRANCE_FEE = 0.001 ether;
    uint256 private constant RAFFLE_DURATION = 7 days;
    uint256 private constant MINIMUM_PLAYERS = 5;
    address private immutable PLAYER = makeAddr("ificouldsmokefearaway");
    address private immutable PLAYER2 = makeAddr("iwouldrollthatmfup");
    uint256 private blockStartTime;

    function setUp() public {
        blockStartTime = block.timestamp;

        // keyHash for Ethereum Sepolia: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae
        // keyHash for Arbitrum Sepolia: 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be

        // vrfCoordinator for Ethereum Sepolia: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
        // vrfCoordinator for Arbitrum Sepolia: 0x5CE8D5A2BC84beb22a398CCA51996F7930313D61

        raffle = new Raffle({
            entranceFee: ENTRANCE_FEE,
            raffleDuration: RAFFLE_DURATION,
            minimumPlayers: MINIMUM_PLAYERS,
            vrfCoordinator: 0x5CE8D5A2BC84beb22a398CCA51996F7930313D61,
            keyHash: 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be,
            subscriptionId: 104653619010104492863966397771792999601147158938402483562660287408202435181427,
            callbackGasLimit: 50000
        });
    }

    function testRaffleStartTime() public view {
        assertEq(raffle.getRaffleStartTime(), blockStartTime);
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
        vm.deal(PLAYER, ENTRANCE_FEE * 5);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE * 5}();
        assertEq(raffle.getNumberOfTickets(PLAYER), 5);
    }

    function testGetTotalTickets() public {
        vm.deal(PLAYER, ENTRANCE_FEE * 4);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE * 4}();

        vm.deal(PLAYER2, ENTRANCE_FEE * 6);
        vm.prank(PLAYER2);
        raffle.enterRaffle{value: ENTRANCE_FEE * 6}();

        assertEq(raffle.getTotalTickets(), 10);
    }

    function testGetMinimumPlayers() public view {
        assertEq(raffle.getMinimumPlayers(), MINIMUM_PLAYERS);
    }

    function testGetRaffleDuration() public view {
        assertEq(raffle.getRaffleDuration(), RAFFLE_DURATION);
    }

    function testRevertIfNotEnoughPlayersToPickWinner() public {
        vm.expectRevert();
        raffle.pickWinner();
    }

    function testRevertIfRaffleDurationNotMet() public {
        vm.deal(PLAYER, ENTRANCE_FEE * MINIMUM_PLAYERS);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE * MINIMUM_PLAYERS}();

        vm.expectRevert();
        raffle.pickWinner();
    }

    // NOTE: This test will change after ChainLink VRF is integrated
    // function testRafflePicksWinner() public {
    //     vm.deal(PLAYER, ENTRANCE_FEE * (MINIMUM_PLAYERS - 3));
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: ENTRANCE_FEE * (MINIMUM_PLAYERS - 3)}();

    //     vm.deal(PLAYER2, ENTRANCE_FEE * 3);
    //     vm.prank(PLAYER2);
    //     raffle.enterRaffle{value: ENTRANCE_FEE * 3}();

    //     // Fast forward time to meet raffle duration
    //     vm.warp(block.timestamp + RAFFLE_DURATION);

    //     // This should not revert now
    //     address winner = raffle.pickWinner();
    //     assertEq(winner, PLAYER2);
    // }

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
