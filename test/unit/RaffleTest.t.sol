// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    uint256 private blockStartTime;
    Raffle private raffle;
    HelperConfig private helperConfig;

    uint256 ENTRANCE_FEE;
    uint256 RAFFLE_DURATION;
    uint256 MINIMUM_PLAYERS;
    address vrfCoordinator;
    bytes32 keyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    uint256 private constant INITIAL_BALANCE = 10 ether;
    address private immutable PLAYER = makeAddr("ificouldsmokefearaway");
    address private immutable PLAYER2 = makeAddr("iwouldrollthatmfup");

    modifier raffleEnteredByMinimumPlayers() {
        // 1. Have enough players enter the raffle.
        // Using a loop makes it robust to changes in MINIMUM_PLAYERS.
        for (uint256 i = 0; i < MINIMUM_PLAYERS; i++) {
            address player = address(uint160(i + 1)); // Create unique player addresses
            vm.deal(player, ENTRANCE_FEE);
            vm.prank(player);
            raffle.enterRaffle{value: ENTRANCE_FEE}();
        }

        // 2. Advance time to meet the duration requirement.
        vm.warp(block.timestamp + RAFFLE_DURATION + 1);

        // Also roll block number to simulate a realistic passage of time.
        vm.roll(block.number + 1);
        _;
    }

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        blockStartTime = block.timestamp;
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        ENTRANCE_FEE = config.entranceFee;
        RAFFLE_DURATION = config.raffleDuration;
        MINIMUM_PLAYERS = config.minimumPlayers;
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    function testDeployerWorksCorrectly() public {
        (Raffle deployedRaffle, HelperConfig deployedConfig) = new DeployRaffle().deployContract();
        assert(address(deployedRaffle) != address(0));
        HelperConfig.NetworkConfig memory config = deployedConfig.getConfig();
        assertEq(config.entranceFee, ENTRANCE_FEE);
        assertEq(config.raffleDuration, RAFFLE_DURATION);
        assertEq(config.minimumPlayers, MINIMUM_PLAYERS);
    }

    function testHelperConfigReturnsSepoliaEthConfig() public {
        vm.chainId(11155111);
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory currentConfig = helper.getConfig();
        HelperConfig.NetworkConfig memory expectedConfig = helper.getSepoliaEthConfig();
        assertEq(currentConfig.entranceFee, expectedConfig.entranceFee);
        assertEq(currentConfig.raffleDuration, expectedConfig.raffleDuration);
        assertEq(currentConfig.minimumPlayers, expectedConfig.minimumPlayers);
        assertEq(currentConfig.vrfCoordinator, expectedConfig.vrfCoordinator);
        assertEq(currentConfig.keyHash, expectedConfig.keyHash);
        assertEq(currentConfig.subscriptionId, expectedConfig.subscriptionId);
        assertEq(currentConfig.callbackGasLimit, expectedConfig.callbackGasLimit);
    }

    function testHelperConfigReturnsSepoliaArbitrumConfig() public {
        vm.chainId(421614);
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory currentConfig = helper.getConfig();
        HelperConfig.NetworkConfig memory expectedConfig = helper.getSepoliaArbitrumConfig();
        assertEq(currentConfig.entranceFee, expectedConfig.entranceFee);
        assertEq(currentConfig.raffleDuration, expectedConfig.raffleDuration);
        assertEq(currentConfig.minimumPlayers, expectedConfig.minimumPlayers);
        assertEq(currentConfig.vrfCoordinator, expectedConfig.vrfCoordinator);
        assertEq(currentConfig.keyHash, expectedConfig.keyHash);
        assertEq(currentConfig.subscriptionId, expectedConfig.subscriptionId);
        assertEq(currentConfig.callbackGasLimit, expectedConfig.callbackGasLimit);
    }

    function testHelperConfigReturnsAnvilConfig() public {
        vm.chainId(31337);
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory currentConfig = helper.getConfig();
        HelperConfig.NetworkConfig memory expectedConfig = helper.getOrCreateAnvilConfig();
        assertEq(currentConfig.entranceFee, expectedConfig.entranceFee);
        assertEq(currentConfig.raffleDuration, expectedConfig.raffleDuration);
        assertEq(currentConfig.minimumPlayers, expectedConfig.minimumPlayers);
        assertEq(currentConfig.vrfCoordinator, expectedConfig.vrfCoordinator);
        assertEq(currentConfig.keyHash, expectedConfig.keyHash);
        assertEq(currentConfig.subscriptionId, expectedConfig.subscriptionId);
        assertEq(currentConfig.callbackGasLimit, expectedConfig.callbackGasLimit);
    }

    function testRaffleStartsInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleStartTime() public view {
        assertEq(raffle.getRaffleStartTime(), blockStartTime);
    }

    function testGetEntranceFee() public view {
        assertEq(raffle.getEntranceFee(), ENTRANCE_FEE);
    }

    function testGetMinimumPlayers() public view {
        assertEq(raffle.getMinimumPlayers(), MINIMUM_PLAYERS);
    }

    function testGetRaffleDuration() public view {
        assertEq(raffle.getRaffleDuration(), RAFFLE_DURATION);
    }

    function testEnterRevertsIfNotEnoughEth() public {
        vm.expectRevert(Raffle.Raffle__NotEnoughMoneyToEnterRaffle.selector);
        raffle.enterRaffle{value: ENTRANCE_FEE - 1}();
    }

    // How do I implement this?
    function testEnterRevertsIfWinnerCalculating() public raffleEnteredByMinimumPlayers {
        // Arrange: Set up the conditions to put the raffle in CALCULATING state.

        // 3. Call performUpkeep to change the state to CALCULATING.
        // checkUpkeep should now return true.
        raffle.performUpkeep("");

        // Act & Assert: Now that the state is CALCULATING, expect a revert.
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
    }

    function testRaffleEntryIsRecorded() public {
        vm.deal(PLAYER, ENTRANCE_FEE * 5);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE * 5}();
        assertEq(raffle.isUserInRaffle(PLAYER), true);
        assertEq(raffle.getRaffleEntrant(0), PLAYER);
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

    function testGetRafflePool() public {
        raffle.enterRaffle{value: ENTRANCE_FEE * 3}();
        assertEq(raffle.getRafflePool(), ENTRANCE_FEE * 3);
    }

    function testEnterEmitsRaffleEnterEvent() public {
        vm.deal(PLAYER, ENTRANCE_FEE);
        vm.prank(PLAYER);

        // Since you can have a maximum of three indexed parameters in an event,
        // the first 3 booleans are set accordingly.
        // The last boolean is for enabling checking of the 'data' part of the event.
        vm.expectEmit(true, false, false, true, address(raffle));
        emit Raffle.RaffleEntered(PLAYER, 1);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
    }

    function testRevertWhenPerformUpkeepNotNeeded() public {
        // Arrange: Enter one player, but don't meet time or player minimums.
        vm.deal(PLAYER, ENTRANCE_FEE);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();

        // Act & Assert: Expect a revert with the correct error.
        // We pass the expected values for the error message to get a more precise check.
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                address(raffle).balance,
                1, // numPlayers
                uint256(Raffle.RaffleState.OPEN)
            )
        );
        raffle.performUpkeep("");
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimePassed() public {
        // Not using modifier here since I need to test time condition specifically.

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, false);

        // Arrange: Enter enough players
        for (uint256 i = 0; i < MINIMUM_PLAYERS; i++) {
            address player = address(uint160(i + 1));
            vm.deal(player, ENTRANCE_FEE);
            vm.prank(player);
            raffle.enterRaffle{value: ENTRANCE_FEE}();
        }

        // Act & Assert 1: Time has not passed, should be false
        (upkeepNeeded,) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, false);

        // Arrange 2: Advance time
        vm.warp(block.timestamp + RAFFLE_DURATION + 1);
        // Also roll block number to simulate a realistic passage of time.
        vm.roll(block.number + 1);

        // Act & Assert 2: Now it should be true
        (upkeepNeeded,) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, true);
    }

    function testPerformUpkeepSwitchesStatusToCalculating() public raffleEnteredByMinimumPlayers {
        // Act
        raffle.performUpkeep("");

        // Assert: Raffle state is now CALCULATING
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    function testPerformUpkeepEmitsRequestedRaffleWinnerEvent() public raffleEnteredByMinimumPlayers {
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();

        // First log is from VrfCorordinator
        // 0th topic is hash of the event signature
        // 1st topic is the indexed requestId
        bytes32 requestedId = entries[1].topics[1];

        assertEq(entries[1].emitter, address(raffle));
        assert(uint256(requestedId) > 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    // The fun part starts here...
    // fulfillRandomWords!!!

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEnteredByMinimumPlayers
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsRaffleAndSendsMoney() public raffleEnteredByMinimumPlayers {
        // Arrange
        uint256 startingTimestamp = raffle.getRaffleStartTime();

        // Why is address(3) the winner?
        // The video had address(1) as winner.
        address expectedWinner = address(3);
        uint256 initialWinnerBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestedId = entries[1].topics[1];

        // Fails with Insufficient Balance
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestedId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = address(recentWinner).balance;
        uint256 endingTimestamp = raffle.getRaffleStartTime();
        uint256 prize = ENTRANCE_FEE * MINIMUM_PLAYERS;
        uint256 rafflePool = raffle.getRafflePool();

        assertEq(recentWinner, expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assertEq(winnerBalance, initialWinnerBalance + prize);
        assertGt(endingTimestamp, startingTimestamp);
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
