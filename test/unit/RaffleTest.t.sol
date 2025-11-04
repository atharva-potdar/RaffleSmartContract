// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract IOnlyRejectEther {
    error IOnlyRejectEther__NoThanks();

    receive() external payable {
        revert IOnlyRejectEther__NoThanks();
    }
}

contract RaffleTest is Test {
    uint256 private blockStartTime;
    Raffle private raffle;
    HelperConfig private helperConfig;

    uint256 entranceFee;
    uint256 raffleDuration;
    uint256 minimumPlayers;
    address vrfCoordinator;
    bytes32 keyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    uint256 private constant INITIAL_BALANCE = 10 ether;
    address private immutable PLAYER = makeAddr("ificouldsmokefearaway");
    address private immutable PLAYER2 = makeAddr("iwouldrollthatmfup");

    modifier raffleEnteredByMinimumPlayers() {
        // 1. Have enough players enter the raffle.
        // Using a loop makes it robust to changes in minimumPlayers.
        for (uint160 i = 1; i <= minimumPlayers; i++) {
            address player = address(i); // Create unique player addresses
            vm.deal(player, entranceFee);
            vm.prank(player);
            raffle.enterRaffle{value: entranceFee}();
        }

        // 2. Advance time to meet the duration requirement.
        vm.warp(block.timestamp + raffleDuration + 1);

        // Also roll block number to simulate a realistic passage of time.
        vm.roll(block.number + 1);
        _;
    }

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        blockStartTime = block.timestamp;
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        raffleDuration = config.raffleDuration;
        minimumPlayers = config.minimumPlayers;
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    /**
     * DeployConfig Tests
     */

    function testDeployerWorksCorrectly() public {
        (Raffle deployedRaffle, HelperConfig deployedConfig) = new DeployRaffle().deployContract();
        assert(address(deployedRaffle) != address(0));
        HelperConfig.NetworkConfig memory config = deployedConfig.getConfig();
        assertEq(config.entranceFee, entranceFee);
        assertEq(config.raffleDuration, raffleDuration);
        assertEq(config.minimumPlayers, minimumPlayers);
    }

    /**
     * HelperConfig Tests
     */

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

    /**
     * Raffle State Tests
     */

    function testRaffleStartsInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleStartTime() public view {
        assertEq(raffle.getRaffleStartTime(), blockStartTime);
    }

    function testGetEntranceFee() public view {
        assertEq(raffle.getEntranceFee(), entranceFee);
    }

    function testGetMinimumPlayers() public view {
        assertEq(raffle.getMinimumPlayers(), minimumPlayers);
    }

    function testGetRaffleDuration() public view {
        assertEq(raffle.getRaffleDuration(), raffleDuration);
    }

    /**
     * Raffle.enterRaffle() Tests
     */

    function testEnterRevertsIfNotEnoughEth() public {
        vm.expectRevert(Raffle.Raffle__NotEnoughMoneyToEnterRaffle.selector);
        raffle.enterRaffle{value: entranceFee - 1}();
    }

    // How do I implement this?
    // Fails on forked ARB_SEP - InvalidFEOpcode
    function testEnterRevertsIfWinnerCalculating() public raffleEnteredByMinimumPlayers {
        // Arrange: Set up the conditions to put the raffle in CALCULATING state.

        // 3. Call performUpkeep to change the state to CALCULATING.
        // checkUpkeep should now return true.
        raffle.performUpkeep("");

        // Act & Assert: Now that the state is CALCULATING, expect a revert.
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleEntryIsRecorded() public {
        vm.deal(PLAYER, entranceFee * 5);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee * 5}();
        assertEq(raffle.isUserInRaffle(PLAYER), true);
        assertEq(raffle.getRaffleEntrant(0), PLAYER);
        assertEq(raffle.getNumberOfTickets(PLAYER), 5);
    }

    function testGetTotalTickets() public {
        vm.deal(PLAYER, entranceFee * 4);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee * 4}();

        vm.deal(PLAYER2, entranceFee * 6);
        vm.prank(PLAYER2);
        raffle.enterRaffle{value: entranceFee * 6}();

        assertEq(raffle.getTotalTickets(), 10);
    }

    function testGetRafflePool() public {
        raffle.enterRaffle{value: entranceFee * 3}();
        assertEq(raffle.getRafflePool(), entranceFee * 3);
    }

    function testEnterEmitsRaffleEnterEvent() public {
        vm.deal(PLAYER, entranceFee);
        vm.prank(PLAYER);

        // Since you can have a maximum of three indexed parameters in an event,
        // the first 3 booleans are set accordingly.
        // The last boolean is for enabling checking of the 'data' part of the event.
        vm.expectEmit(true, false, false, true, address(raffle));
        emit Raffle.RaffleEntered(PLAYER, 1);
        raffle.enterRaffle{value: entranceFee}();
    }

    /**
     * Raffle.checkUpkeep() and Raffle.performUpkeep() Tests
     */

    function testRevertWhenPerformUpkeepNotNeeded() public {
        // Arrange: Enter one player, but don't meet time or player minimums.
        vm.deal(PLAYER, entranceFee);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

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
        for (uint160 i = 1; i <= minimumPlayers; i++) {
            address player = address(i);
            vm.deal(player, entranceFee);
            vm.prank(player);
            raffle.enterRaffle{value: entranceFee}();
        }

        // Act & Assert 1: Time has not passed, should be false
        (upkeepNeeded,) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, false);

        // Arrange 2: Advance time
        vm.warp(block.timestamp + raffleDuration + 1);
        // Also roll block number to simulate a realistic passage of time.
        vm.roll(block.number + 1);

        // Act & Assert 2: Now it should be true
        (upkeepNeeded,) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, true);
    }

    // Fails on forked ARB_SEP - InvalidFEOpcode
    function testPerformUpkeepSwitchesStatusToCalculating() public raffleEnteredByMinimumPlayers {
        // Act
        raffle.performUpkeep("");

        // Assert: Raffle state is now CALCULATING
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    // Fails on forked ARB_SEP - InvalidFEOpcode
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

    /**
     * Raffle.fulfillRandomWords() Tests
     */

    // Fails on forked ARB_SEP - "reverted but without data"
    // Fails on forked ETH_SEP - "reverted but without data"
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEnteredByMinimumPlayers
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    // Fails on forked ARB_SEP - InvalidFEOpcode
    // Fails on forked ETH_SEP - unrecognized function selector 0x808974ff for contract 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, which has no fallback function.
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
        uint256 prize = entranceFee * minimumPlayers;

        assertEq(recentWinner, expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assertEq(winnerBalance, initialWinnerBalance + prize);
        assertGt(endingTimestamp, startingTimestamp);
    }

    // Fails on forked ARB_SEP - InvalidFEOpcode
    // Fails on forked ETH_SEP - unrecognized function selector 0x808974ff for contract 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, which has no fallback function
    function testFulfillRandomWordsRevertsIfTransferFails() public {
        // Arrange
        // 1. Create a contract that will reject Ether payments.
        IOnlyRejectEther winnerContract = new IOnlyRejectEther();
        address winnerAddress = address(winnerContract);

        // 3. Fund and enter the raffle as the rejecting contract.
        vm.deal(address(0), entranceFee); // Fund the contract to enter the raffle
        vm.prank(address(0));
        raffle.enterRaffle{value: entranceFee}();

        vm.deal(address(1), entranceFee); // Fund another player
        vm.prank(address(1));
        raffle.enterRaffle{value: entranceFee}();

        // Our "Determistic" mock always picks the last entrant
        vm.deal(winnerAddress, entranceFee);
        vm.prank(winnerAddress);
        raffle.enterRaffle{value: entranceFee}();

        // 4. Advance time to allow for winner selection.
        vm.warp(block.timestamp + raffleDuration + 1);
        vm.roll(block.number + 1);

        // Act
        // 5. Request a winner from the VRF coordinator.
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        // 6. Fulfill the request and expect the `Raffle__TransferFailed` error.
        vm.expectEmit(true, false, false, true, address(raffle));
        emit Raffle.TransferFailed(winnerAddress, entranceFee * 3);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
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
