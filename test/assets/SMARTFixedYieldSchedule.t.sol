// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockedERC20Token } from "../utils/mocks/MockedERC20Token.sol";
import { SMARTFixedYieldSchedule } from "../../contracts/extensions/yield/schedules/fixed/SMARTFixedYieldSchedule.sol";
import { ISMARTYield } from "../../contracts/extensions/yield/ISMARTYield.sol";

contract MockSMARTToken is MockedERC20Token {
    mapping(address => uint256) private _yieldBasisPerUnit;
    mapping(uint256 => uint256) private _totalSupplyAtTimestamp;
    mapping(address => mapping(uint256 => uint256)) private _balanceOfAt;
    IERC20 private _yieldTokenAddress;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address yieldTokenAddr
    )
        MockedERC20Token(name, symbol, decimals)
    {
        _yieldTokenAddress = IERC20(yieldTokenAddr);
    }

    function setYieldBasisPerUnit(address holder, uint256 basis) external {
        _yieldBasisPerUnit[holder] = basis;
    }

    function yieldBasisPerUnit(address holder) external view returns (uint256) {
        return _yieldBasisPerUnit[holder] > 0 ? _yieldBasisPerUnit[holder] : 1000; // Default 1000 basis
    }

    function yieldToken() external view returns (IERC20) {
        return _yieldTokenAddress;
    }

    function setTotalSupplyAt(uint256 timestamp, uint256 supply) external {
        _totalSupplyAtTimestamp[timestamp] = supply;
    }

    function totalSupplyAt(uint256 timestamp) external view returns (uint256) {
        return _totalSupplyAtTimestamp[timestamp] > 0 ? _totalSupplyAtTimestamp[timestamp] : this.totalSupply();
    }

    function setBalanceOfAt(address holder, uint256 timestamp, uint256 balance) external {
        _balanceOfAt[holder][timestamp] = balance;
    }

    function balanceOfAt(address holder, uint256 timestamp) external view returns (uint256) {
        return _balanceOfAt[holder][timestamp] > 0 ? _balanceOfAt[holder][timestamp] : this.balanceOf(holder);
    }
}

contract SMARTFixedYieldScheduleTest is Test {
    SMARTFixedYieldSchedule public yieldSchedule;
    MockSMARTToken public smartToken;
    MockedERC20Token public underlyingToken;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public forwarder = address(0x4);

    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 public constant START_DATE_OFFSET = 1 days;
    uint256 public constant END_DATE_OFFSET = 10 days;
    uint256 public constant INTERVAL = 1 days;
    uint256 public constant RATE = 500; // 5%

    uint256 public startDate;
    uint256 public endDate;

    function setUp() public {
        startDate = block.timestamp + START_DATE_OFFSET;
        endDate = block.timestamp + END_DATE_OFFSET;

        // Deploy underlying token
        underlyingToken = new MockedERC20Token("Underlying", "UND", 18);

        // Deploy mock SMART token
        smartToken = new MockSMARTToken("Smart Token", "SMART", 18, address(underlyingToken));

        // Deploy yield schedule
        yieldSchedule =
            new SMARTFixedYieldSchedule(address(smartToken), owner, startDate, endDate, RATE, INTERVAL, forwarder);

        // Setup tokens
        underlyingToken.mint(address(this), INITIAL_SUPPLY);
        underlyingToken.mint(user1, INITIAL_SUPPLY);
        underlyingToken.mint(user2, INITIAL_SUPPLY);

        smartToken.mint(user1, 1000e18);
        smartToken.mint(user2, 500e18);

        // Setup historical data
        smartToken.setTotalSupplyAt(startDate + 1 days, 1500e18);
        smartToken.setBalanceOfAt(user1, startDate + 1 days, 1000e18);
        smartToken.setBalanceOfAt(user2, startDate + 1 days, 500e18);
    }

    function test_InitialState() public view {
        assertEq(address(yieldSchedule.token()), address(smartToken));
        assertEq(address(yieldSchedule.underlyingAsset()), address(underlyingToken));
        assertEq(yieldSchedule.startDate(), startDate);
        assertEq(yieldSchedule.endDate(), endDate);
        assertEq(yieldSchedule.rate(), RATE);
        assertEq(yieldSchedule.interval(), INTERVAL);
    }

    function test_PeriodCalculations() public {
        // Before start
        assertEq(yieldSchedule.currentPeriod(), 0);
        assertEq(yieldSchedule.lastCompletedPeriod(), 0);

        // Move to start date
        vm.warp(startDate);
        assertEq(yieldSchedule.currentPeriod(), 1);
        assertEq(yieldSchedule.lastCompletedPeriod(), 0);

        // Move to first period end
        vm.warp(startDate + INTERVAL);
        assertEq(yieldSchedule.currentPeriod(), 2);
        assertEq(yieldSchedule.lastCompletedPeriod(), 1);

        // Move to end date
        vm.warp(endDate);
        uint256 totalPeriods = ((endDate - startDate) / INTERVAL) + 1;
        assertEq(yieldSchedule.currentPeriod(), totalPeriods);
        assertEq(yieldSchedule.lastCompletedPeriod(), totalPeriods);
    }

    function test_PeriodEndTimestamps() public view {
        uint256[] memory periods = yieldSchedule.allPeriods();
        assertTrue(periods.length > 0);

        // Check first period end
        assertEq(yieldSchedule.periodEnd(1), startDate + INTERVAL);

        // Check last period doesn't exceed end date
        uint256 lastPeriod = periods.length;
        assertTrue(yieldSchedule.periodEnd(lastPeriod) <= endDate);
    }

    function test_TimeUntilNextPeriod() public {
        // Before start
        assertEq(yieldSchedule.timeUntilNextPeriod(), startDate - block.timestamp);

        // At start
        vm.warp(startDate);
        assertEq(yieldSchedule.timeUntilNextPeriod(), INTERVAL);

        // Halfway through first period
        vm.warp(startDate + INTERVAL / 2);
        assertEq(yieldSchedule.timeUntilNextPeriod(), INTERVAL / 2);

        // After end
        vm.warp(endDate + 1);
        assertEq(yieldSchedule.timeUntilNextPeriod(), 0);
    }

    function test_YieldCalculations() public {
        // Move to after first period
        vm.warp(startDate + INTERVAL + 1);

        uint256 yieldForUser1 = yieldSchedule.calculateAccruedYield(user1);
        uint256 yieldForUser2 = yieldSchedule.calculateAccruedYield(user2);

        assertTrue(yieldForUser1 > 0);
        assertTrue(yieldForUser2 > 0);
        assertTrue(yieldForUser1 > yieldForUser2); // user1 has more tokens
    }

    function test_TopUpUnderlyingAsset() public {
        uint256 topUpAmount = 1000e18;

        vm.startPrank(user1);
        underlyingToken.approve(address(yieldSchedule), topUpAmount);

        vm.expectEmit(true, false, false, true);
        emit SMARTFixedYieldSchedule.UnderlyingAssetTopUp(user1, topUpAmount);

        yieldSchedule.topUpUnderlyingAsset(topUpAmount);
        vm.stopPrank();

        assertEq(underlyingToken.balanceOf(address(yieldSchedule)), topUpAmount);
    }

    function test_ClaimYield() public {
        // Setup: Fund the contract and move to after first period
        uint256 fundAmount = 100_000e18;
        underlyingToken.transfer(address(yieldSchedule), fundAmount);
        vm.warp(startDate + INTERVAL + 1);

        uint256 initialBalance = underlyingToken.balanceOf(user1);

        // Calculate yield for completed periods only (what claimYield actually pays)
        uint256 lastCompleted = yieldSchedule.lastCompletedPeriod();
        uint256 basis = smartToken.yieldBasisPerUnit(user1);
        uint256 expectedClaimAmount = 0;

        for (uint256 period = 1; period <= lastCompleted; period++) {
            uint256 balance = smartToken.balanceOfAt(user1, yieldSchedule.periodEnd(period));
            if (balance > 0) {
                expectedClaimAmount += (balance * basis * 500) / 10_000; // rate = 500, RATE_BASIS_POINTS = 10000
            }
        }

        vm.prank(user1);
        yieldSchedule.claimYield();

        uint256 actualBalance = underlyingToken.balanceOf(user1);
        uint256 expectedBalance = initialBalance + expectedClaimAmount;

        assertEq(actualBalance, expectedBalance);
        assertEq(yieldSchedule.lastClaimedPeriod(user1), lastCompleted);
    }

    function test_ClaimYield_NoYieldAvailable() public {
        // Try to claim before any periods complete
        vm.prank(user1);
        vm.expectRevert(SMARTFixedYieldSchedule.NoYieldAvailable.selector);
        yieldSchedule.claimYield();
    }

    function test_WithdrawUnderlyingAsset() public {
        uint256 withdrawAmount = 1000e18;
        underlyingToken.transfer(address(yieldSchedule), withdrawAmount);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SMARTFixedYieldSchedule.UnderlyingAssetWithdrawn(user1, withdrawAmount);

        yieldSchedule.withdrawUnderlyingAsset(user1, withdrawAmount);

        assertEq(underlyingToken.balanceOf(user1), INITIAL_SUPPLY + withdrawAmount);
    }

    function test_WithdrawUnderlyingAsset_OnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        yieldSchedule.withdrawUnderlyingAsset(user1, 1000e18);
    }

    function test_WithdrawAllUnderlyingAsset() public {
        uint256 depositAmount = 1000e18;
        underlyingToken.transfer(address(yieldSchedule), depositAmount);

        vm.prank(owner);
        yieldSchedule.withdrawAllUnderlyingAsset(user1);

        assertEq(underlyingToken.balanceOf(address(yieldSchedule)), 0);
        assertEq(underlyingToken.balanceOf(user1), INITIAL_SUPPLY + depositAmount);
    }

    function test_PauseUnpause() public {
        vm.prank(owner);
        yieldSchedule.pause();

        // Should revert when paused
        vm.prank(user1);
        vm.expectRevert();
        yieldSchedule.topUpUnderlyingAsset(1000e18);

        vm.prank(owner);
        yieldSchedule.unpause();

        // Should work after unpause
        vm.startPrank(user1);
        underlyingToken.approve(address(yieldSchedule), 1000e18);
        yieldSchedule.topUpUnderlyingAsset(1000e18);
        vm.stopPrank();
    }

    function test_TotalYieldForNextPeriod() public {
        uint256 totalYield = yieldSchedule.totalYieldForNextPeriod();
        assertTrue(totalYield > 0);

        // After end date should be 0
        vm.warp(endDate + 1);
        assertEq(yieldSchedule.totalYieldForNextPeriod(), 0);
    }

    function test_TotalUnclaimedYield() public {
        // Before any periods complete
        assertEq(yieldSchedule.totalUnclaimedYield(), 0);

        // After first period
        vm.warp(startDate + INTERVAL + 1);
        uint256 unclaimed = yieldSchedule.totalUnclaimedYield();
        assertTrue(unclaimed > 0);
    }

    function test_InvalidConstructorParameters() public {
        // Invalid start date (in the past)
        vm.expectRevert(SMARTFixedYieldSchedule.InvalidStartDate.selector);
        new SMARTFixedYieldSchedule(address(smartToken), owner, block.timestamp - 1, endDate, RATE, INTERVAL, forwarder);

        // Invalid end date (before start)
        vm.expectRevert(SMARTFixedYieldSchedule.InvalidEndDate.selector);
        new SMARTFixedYieldSchedule(address(smartToken), owner, startDate, startDate - 1, RATE, INTERVAL, forwarder);

        // Invalid rate (zero)
        vm.expectRevert(SMARTFixedYieldSchedule.InvalidRate.selector);
        new SMARTFixedYieldSchedule(address(smartToken), owner, startDate, endDate, 0, INTERVAL, forwarder);

        // Invalid interval (zero)
        vm.expectRevert(SMARTFixedYieldSchedule.InvalidInterval.selector);
        new SMARTFixedYieldSchedule(address(smartToken), owner, startDate, endDate, RATE, 0, forwarder);
    }

    function test_InvalidPeriod() public {
        vm.expectRevert(SMARTFixedYieldSchedule.InvalidPeriod.selector);
        yieldSchedule.periodEnd(0);

        vm.expectRevert(SMARTFixedYieldSchedule.InvalidPeriod.selector);
        yieldSchedule.periodEnd(1000);
    }

    function test_ScheduleNotActive() public {
        vm.expectRevert(SMARTFixedYieldSchedule.ScheduleNotActive.selector);
        yieldSchedule.calculateAccruedYield(user1);
    }

    function test_WithdrawInvalidAmount() public {
        vm.prank(owner);
        vm.expectRevert(SMARTFixedYieldSchedule.InvalidAmount.selector);
        yieldSchedule.withdrawUnderlyingAsset(user1, 0);
    }

    function test_WithdrawToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(SMARTFixedYieldSchedule.InvalidUnderlyingAsset.selector);
        yieldSchedule.withdrawUnderlyingAsset(address(0), 1000e18);
    }

    function test_InsufficientUnderlyingBalance() public {
        vm.prank(owner);
        vm.expectRevert(SMARTFixedYieldSchedule.InsufficientUnderlyingBalance.selector);
        yieldSchedule.withdrawUnderlyingAsset(user1, 1000e18);
    }
}
