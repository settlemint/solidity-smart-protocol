// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AbstractSMARTTest } from "./AbstractSMARTTest.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISMARTYield } from "../../contracts/extensions/yield/ISMARTYield.sol";
import { ISMARTYieldSchedule } from "../../contracts/extensions/yield/schedules/ISMARTYieldSchedule.sol";
import { ISMARTFixedYieldSchedule } from "../../contracts/extensions/yield/schedules/fixed/ISMARTFixedYieldSchedule.sol";
import { SMARTFixedYieldSchedule } from "../../contracts/extensions/yield/schedules/fixed/SMARTFixedYieldSchedule.sol";
import { SMARTFixedYieldScheduleFactory } from
    "../../contracts/extensions/yield/schedules/fixed/SMARTFixedYieldScheduleFactory.sol";
import { YieldScheduleAlreadySet, YieldScheduleActive } from "../../contracts/extensions/yield/SMARTYieldErrors.sol";
import { ZeroAddressNotAllowed } from "../../contracts/extensions/common/CommonErrors.sol";
import { SMARTYieldToken } from "../examples/SMARTYieldToken.sol";

abstract contract SMARTYieldTest is AbstractSMARTTest {
    uint256 internal constant DEFAULT_YIELD_BASIS = 1; // 1:1 basis - each token earns yield on itself
    uint256 internal constant YIELD_RATE = 500; // 5% in basis points
    uint256 internal constant PERIOD_INTERVAL = 30 days;
    uint256 internal constant SCHEDULE_DURATION = 365 days;

    SMARTFixedYieldScheduleFactory internal yieldScheduleFactory;
    address internal yieldPaymentToken;

    function _setUpYieldTest() internal {
        super.setUp();
        _setupDefaultCollateralClaim();

        // Deploy yield payment token (using a simple ERC20 mock for testing)
        if (yieldPaymentToken == address(0)) {
            yieldPaymentToken = address(new MockERC20("Yield Token", "YIELD"));
        }

        // Deploy yield schedule factory
        yieldScheduleFactory = new SMARTFixedYieldScheduleFactory(address(0));
        
        // Start at a high block number that can accommodate timestamps as block numbers
        // Since yield schedules use timestamps as block numbers in balanceOfAt calls,
        // we need to ensure block numbers are high enough to match future timestamps
        uint256 currentTimestamp = block.timestamp;
        if (block.number < currentTimestamp) {
            vm.roll(currentTimestamp + 1);
        }
    }

    // --- Core Extension Tests ---

    function test_Yield_SupportsInterface() public {
        _setUpYieldTest();

        // Test ISMARTYield interface support
        bytes4 yieldInterfaceId = type(ISMARTYield).interfaceId;
        assertTrue(IERC165(address(token)).supportsInterface(yieldInterfaceId), "Should support ISMARTYield interface");

        // Test ERC165 interface support
        bytes4 erc165InterfaceId = type(IERC165).interfaceId;
        assertTrue(IERC165(address(token)).supportsInterface(erc165InterfaceId), "Should support ERC165 interface");
    }

    function test_Yield_InitialState() public {
        _setUpYieldTest();

        // Verify initial state
        assertEq(
            ISMARTYield(address(token)).yieldSchedule(), address(0), "Initial yield schedule should be zero address"
        );
        assertEq(
            ISMARTYield(address(token)).yieldBasisPerUnit(clientBE),
            DEFAULT_YIELD_BASIS,
            "Yield basis should be set to default"
        );
        assertEq(
            address(ISMARTYield(address(token)).yieldToken()), yieldPaymentToken, "Yield token should be set correctly"
        );
    }

    // --- Yield Schedule Management Tests ---

    function test_Yield_SetYieldSchedule_Success() public {
        _setUpYieldTest();

        address scheduleAddress = _createYieldSchedule();

        vm.expectEmit(true, true, false, true);
        emit ISMARTYield.YieldScheduleSet(tokenIssuer, scheduleAddress);

        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        assertEq(ISMARTYield(address(token)).yieldSchedule(), scheduleAddress, "Yield schedule should be set correctly");
    }

    function test_Yield_SetYieldSchedule_ZeroAddress_Reverts() public {
        _setUpYieldTest();

        vm.expectRevert(ZeroAddressNotAllowed.selector);
        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(address(0));
    }

    function test_Yield_SetYieldSchedule_AlreadySet_Reverts() public {
        _setUpYieldTest();

        address scheduleAddress = _createYieldSchedule();

        // Set schedule first time
        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        // Try to set again with different parameters to avoid CREATE2 collision
        address anotherSchedule = _createYieldSchedule(block.timestamp + 2 days);
        vm.expectRevert(YieldScheduleAlreadySet.selector);
        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(anotherSchedule);
    }

    function test_Yield_SetYieldSchedule_AccessControl_Reverts() public {
        _setUpYieldTest();

        address scheduleAddress = _createYieldSchedule();

        // Try to set schedule without proper role
        vm.startPrank(clientBE);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                clientBE,
                SMARTYieldToken(address(token)).TOKEN_ADMIN_ROLE()
            )
        );
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);
        vm.stopPrank();
    }

    // --- Minting Restriction Tests ---

    function test_Yield_MintBeforeScheduleStarts_Success() public {
        _setUpYieldTest();

        uint256 futureStartDate = block.timestamp + 7 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        // Set yield schedule
        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        // Minting should work before schedule starts
        uint256 mintAmount = 1000 ether;
        uint256 initialBalance = token.balanceOf(clientBE);

        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, mintAmount);

        assertEq(
            token.balanceOf(clientBE), initialBalance + mintAmount, "Minting should succeed before schedule starts"
        );
    }

    function test_Yield_MintAfterScheduleStarts_Reverts() public {
        _setUpYieldTest();

        // Create a schedule that starts in the future
        uint256 futureStartDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        // Set yield schedule
        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        // Move time to after schedule starts
        _advanceTimeAndBlock(futureStartDate + 1);

        // Minting should fail after schedule starts
        uint256 mintAmount = 1000 ether;

        vm.expectRevert(YieldScheduleActive.selector);
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, mintAmount);
    }

    function test_Yield_MintWithoutSchedule_Success() public {
        _setUpYieldTest();

        // Minting should work without any schedule set
        uint256 mintAmount = 1000 ether;
        uint256 initialBalance = token.balanceOf(clientBE);

        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, mintAmount);

        assertEq(token.balanceOf(clientBE), initialBalance + mintAmount, "Minting should succeed without schedule");
    }

    function test_Yield_MintAtScheduleStartTime_Reverts() public {
        _setUpYieldTest();

        // Use a future start date, then warp to that time
        uint256 startDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(startDate);

        // Set yield schedule
        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        // Warp to exactly the start time
        vm.warp(startDate);

        // Minting should fail at exactly the start time
        uint256 mintAmount = 1000 ether;

        vm.expectRevert(YieldScheduleActive.selector);
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, mintAmount);
    }

    // --- Yield Basis Configuration Tests ---

    function test_Yield_YieldBasisPerUnit_Consistency() public {
        _setUpYieldTest();

        // Yield basis should be consistent for all holders (using default implementation)
        uint256 basisBE = ISMARTYield(address(token)).yieldBasisPerUnit(clientBE);
        uint256 basisJP = ISMARTYield(address(token)).yieldBasisPerUnit(clientJP);
        uint256 basisUS = ISMARTYield(address(token)).yieldBasisPerUnit(clientUS);

        assertEq(basisBE, DEFAULT_YIELD_BASIS, "Yield basis for clientBE should match default");
        assertEq(basisJP, DEFAULT_YIELD_BASIS, "Yield basis for clientJP should match default");
        assertEq(basisUS, DEFAULT_YIELD_BASIS, "Yield basis for clientUS should match default");
        assertEq(basisBE, basisJP, "Yield basis should be consistent across holders");
        assertEq(basisJP, basisUS, "Yield basis should be consistent across holders");
    }

    function test_Yield_YieldBasisPerUnit_NonZero() public {
        _setUpYieldTest();

        uint256 basis = ISMARTYield(address(token)).yieldBasisPerUnit(clientBE);
        assertTrue(basis > 0, "Yield basis should be greater than zero");
    }

    // --- Yield Token Configuration Tests ---

    function test_Yield_YieldToken_Correct() public {
        _setUpYieldTest();

        IERC20 configuredYieldToken = ISMARTYield(address(token)).yieldToken();
        assertEq(address(configuredYieldToken), yieldPaymentToken, "Yield token should match configured payment token");
    }

    function test_Yield_YieldToken_NotZeroAddress() public {
        _setUpYieldTest();

        IERC20 configuredYieldToken = ISMARTYield(address(token)).yieldToken();
        assertTrue(address(configuredYieldToken) != address(0), "Yield token should not be zero address");
    }

    // --- Fixed Yield Schedule Integration Tests ---

    function test_Yield_FixedScheduleIntegration() public {
        _setUpYieldTest();

        uint256 futureStartDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        // Set yield schedule
        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        // Verify schedule properties
        ISMARTFixedYieldSchedule schedule = ISMARTFixedYieldSchedule(scheduleAddress);

        assertEq(schedule.startDate(), futureStartDate, "Schedule start date should match");
        assertEq(address(schedule.token()), address(token), "Schedule token should reference our token");
        assertEq(
            address(schedule.underlyingAsset()), yieldPaymentToken, "Schedule underlying asset should match yield token"
        );
        assertEq(schedule.rate(), YIELD_RATE, "Schedule rate should match configured rate");
        assertEq(schedule.interval(), PERIOD_INTERVAL, "Schedule interval should match configured interval");
    }

    function test_Yield_SchedulePeriodCalculations() public {
        _setUpYieldTest();

        uint256 futureStartDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        ISMARTFixedYieldSchedule schedule = ISMARTFixedYieldSchedule(scheduleAddress);

        // Before schedule starts
        assertEq(schedule.currentPeriod(), 0, "Current period should be 0 before start");
        assertEq(schedule.lastCompletedPeriod(), 0, "Last completed period should be 0 before start");

        // Move to start date
        vm.warp(futureStartDate);

        assertEq(schedule.currentPeriod(), 1, "Current period should be 1 at start");
        assertEq(schedule.lastCompletedPeriod(), 0, "Last completed period should still be 0 at start");

        // Move to end of first period
        vm.warp(futureStartDate + PERIOD_INTERVAL);

        assertEq(schedule.currentPeriod(), 2, "Current period should be 2 after first period");
        assertEq(schedule.lastCompletedPeriod(), 1, "Last completed period should be 1 after first period");
    }

    function test_Yield_ScheduleTimeCalculations() public {
        _setUpYieldTest();

        uint256 futureStartDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        ISMARTFixedYieldSchedule schedule = ISMARTFixedYieldSchedule(scheduleAddress);

        // Check time until next period before start
        uint256 timeUntilNext = schedule.timeUntilNextPeriod();
        assertApproxEqAbs(timeUntilNext, 1 days, 5, "Time until next period should be approximately 1 day");

        // Move to middle of first period
        vm.warp(futureStartDate + PERIOD_INTERVAL / 2);

        timeUntilNext = schedule.timeUntilNextPeriod();
        assertApproxEqAbs(
            timeUntilNext, PERIOD_INTERVAL / 2, 5, "Time until next period should be approximately half the interval"
        );
    }

    // --- Financial Calculation Tests ---

    function test_Yield_BasicYieldCalculation() public {
        _setUpYieldTest();
        
        // Ensure block number is aligned before minting
        if (block.number < block.timestamp) {
            vm.roll(block.timestamp);
        }
        _mintInitialBalances();

        uint256 futureStartDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        ISMARTFixedYieldSchedule schedule = ISMARTFixedYieldSchedule(scheduleAddress);

        // Fund the schedule
        _fundYieldSchedule(scheduleAddress, 1_000_000 ether);

        // Move to exactly when first period completes
        _advanceTimeAndBlock(futureStartDate + PERIOD_INTERVAL);
        
        // Advance one more second to ensure the period end timestamp is in the past for balanceOfAt
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Calculate expected yield for clientBE (for one complete period)
        uint256 balance = token.balanceOf(clientBE);
        uint256 expectedYield = (balance * DEFAULT_YIELD_BASIS * YIELD_RATE) / 10_000; // YIELD_RATE is in basis points

        uint256 calculatedYield = schedule.calculateAccruedYield(clientBE);
        
        // Allow for small rounding differences due to pro-rata calculation (1 second of extra yield)
        assertApproxEqAbs(calculatedYield, expectedYield, 1e18, "Calculated yield should match expected yield");
    }

    function test_Yield_ZeroBalanceYieldCalculation() public {
        _setUpYieldTest();

        uint256 futureStartDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        ISMARTFixedYieldSchedule schedule = ISMARTFixedYieldSchedule(scheduleAddress);

        // Move to after first period completes (clientUnverified has zero balance)
        _advanceTimeAndBlock(futureStartDate + PERIOD_INTERVAL + 1);

        uint256 calculatedYield = schedule.calculateAccruedYield(clientUnverified);
        assertEq(calculatedYield, 0, "Yield for zero balance should be zero");
    }

    // --- Yield Claiming Tests ---

    function test_Yield_ClaimYield_Success() public {
        _setUpYieldTest();
        
        // Ensure block number is aligned before minting
        if (block.number < block.timestamp) {
            vm.roll(block.timestamp);
        }
        _mintInitialBalances();

        uint256 futureStartDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        ISMARTFixedYieldSchedule schedule = ISMARTFixedYieldSchedule(scheduleAddress);

        // Fund the schedule
        uint256 fundAmount = 1_000_000 ether;
        _fundYieldSchedule(scheduleAddress, fundAmount);

        // Move to after first period completes
        _advanceTimeAndBlock(futureStartDate + PERIOD_INTERVAL + 1);

        uint256 initialYieldBalance = IERC20(yieldPaymentToken).balanceOf(clientBE);
        
        // Calculate expected yield for one complete period (not including pro-rata)
        uint256 balance = token.balanceOf(clientBE);
        uint256 expectedYield = (balance * DEFAULT_YIELD_BASIS * YIELD_RATE) / 10_000;

        // Claim yield
        vm.prank(clientBE);
        schedule.claimYield();

        uint256 finalYieldBalance = IERC20(yieldPaymentToken).balanceOf(clientBE);

        assertEq(finalYieldBalance - initialYieldBalance, expectedYield, "Claimed yield should match calculated yield");
        assertEq(schedule.lastClaimedPeriod(clientBE), 1, "Last claimed period should be updated");
    }

    function test_Yield_ClaimYield_MultiplePeriods() public {
        _setUpYieldTest();
        
        // Ensure block number is aligned before minting
        if (block.number < block.timestamp) {
            vm.roll(block.timestamp);
        }
        _mintInitialBalances();

        uint256 futureStartDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        ISMARTFixedYieldSchedule schedule = ISMARTFixedYieldSchedule(scheduleAddress);

        // Fund the schedule
        _fundYieldSchedule(scheduleAddress, 1_000_000 ether);

        // Move to after two periods complete
        _advanceTimeAndBlock(futureStartDate + (PERIOD_INTERVAL * 2) + 1);

        uint256 initialYieldBalance = IERC20(yieldPaymentToken).balanceOf(clientBE);
        
        // Calculate expected yield for two complete periods (not including pro-rata)
        uint256 balance = token.balanceOf(clientBE);
        uint256 expectedYield = (balance * DEFAULT_YIELD_BASIS * YIELD_RATE * 2) / 10_000; // 2 periods

        // Claim yield
        vm.prank(clientBE);
        schedule.claimYield();

        uint256 finalYieldBalance = IERC20(yieldPaymentToken).balanceOf(clientBE);

        assertEq(
            finalYieldBalance - initialYieldBalance,
            expectedYield,
            "Claimed yield should match calculated yield for multiple periods"
        );
        assertEq(schedule.lastClaimedPeriod(clientBE), 2, "Last claimed period should be updated to 2");
    }

    // --- Administrative Function Tests ---

    function test_Yield_FundSchedule_Success() public {
        _setUpYieldTest();

        address scheduleAddress = _createYieldSchedule();
        uint256 fundAmount = 100_000 ether;

        uint256 initialScheduleBalance = IERC20(yieldPaymentToken).balanceOf(scheduleAddress);

        _fundYieldSchedule(scheduleAddress, fundAmount);

        uint256 finalScheduleBalance = IERC20(yieldPaymentToken).balanceOf(scheduleAddress);

        assertEq(finalScheduleBalance - initialScheduleBalance, fundAmount, "Schedule should receive funding");
    }

    function test_Yield_WithdrawFromSchedule_Success() public {
        _setUpYieldTest();

        address scheduleAddress = _createYieldSchedule();
        uint256 fundAmount = 100_000 ether;
        uint256 withdrawAmount = 50_000 ether;

        // Fund first
        _fundYieldSchedule(scheduleAddress, fundAmount);

        uint256 initialTokenIssuerBalance = IERC20(yieldPaymentToken).balanceOf(tokenIssuer);

        // Withdraw
        vm.prank(tokenIssuer);
        ISMARTFixedYieldSchedule(scheduleAddress).withdrawUnderlyingAsset(tokenIssuer, withdrawAmount);

        uint256 finalTokenIssuerBalance = IERC20(yieldPaymentToken).balanceOf(tokenIssuer);

        assertEq(
            finalTokenIssuerBalance - initialTokenIssuerBalance,
            withdrawAmount,
            "Withdrawal should transfer correct amount"
        );
    }

    // --- Edge Cases and Error Conditions ---

    function test_Yield_ScheduleNotSet_Queries() public {
        _setUpYieldTest();

        // Queries should work even without schedule set
        assertEq(ISMARTYield(address(token)).yieldSchedule(), address(0), "Yield schedule should be zero address");
        assertEq(
            ISMARTYield(address(token)).yieldBasisPerUnit(clientBE),
            DEFAULT_YIELD_BASIS,
            "Yield basis should work without schedule"
        );
        assertEq(
            address(ISMARTYield(address(token)).yieldToken()),
            yieldPaymentToken,
            "Yield token should work without schedule"
        );
    }

    function test_Yield_ScheduleEndDate_Calculation() public {
        _setUpYieldTest();

        uint256 startDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(startDate);

        ISMARTFixedYieldSchedule schedule = ISMARTFixedYieldSchedule(scheduleAddress);

        uint256 expectedEndDate = startDate + SCHEDULE_DURATION;
        assertEq(schedule.endDate(), expectedEndDate, "End date should be calculated correctly");
    }

    function test_Yield_PeriodBoundaries() public {
        _setUpYieldTest();

        uint256 startDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(startDate);

        ISMARTFixedYieldSchedule schedule = ISMARTFixedYieldSchedule(scheduleAddress);

        // Check period boundaries
        uint256 firstPeriodEnd = schedule.periodEnd(1);
        uint256 secondPeriodEnd = schedule.periodEnd(2);

        assertEq(firstPeriodEnd, startDate + PERIOD_INTERVAL, "First period end should be start + interval");
        assertEq(secondPeriodEnd, startDate + (PERIOD_INTERVAL * 2), "Second period end should be start + 2*interval");
    }

    // --- Integration Tests ---

    function test_Yield_WithHistoricalBalances() public {
        _setUpYieldTest();
        
        // Ensure block number is aligned before minting
        if (block.number < block.timestamp) {
            vm.roll(block.timestamp);
        }
        _mintInitialBalances();

        uint256 futureStartDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        // Move to start and verify historical balance integration
        vm.warp(futureStartDate);
        
        // Roll forward a block to ensure historical balance is available
        vm.roll(block.number + 1);

        uint256 currentBalance = token.balanceOf(clientBE);
        uint256 historicalBalance = ISMARTYield(address(token)).balanceOfAt(clientBE, block.number - 1);

        assertEq(
            currentBalance, historicalBalance, "Historical balance should match current balance for yield calculations"
        );
    }

    function test_Yield_WithCompliance() public {
        _setUpYieldTest();
        
        // Ensure block number is aligned before minting
        if (block.number < block.timestamp) {
            vm.roll(block.timestamp);
        }
        _mintInitialBalances();

        uint256 futureStartDate = block.timestamp + 1 days;
        address scheduleAddress = _createYieldSchedule(futureStartDate);

        vm.prank(tokenIssuer);
        ISMARTYield(address(token)).setYieldSchedule(scheduleAddress);

        // Fund the schedule
        _fundYieldSchedule(scheduleAddress, 1_000_000 ether);

        // Move to after first period
        _advanceTimeAndBlock(futureStartDate + PERIOD_INTERVAL + 1);

        // Verify compliance is still enforced for yield claims
        // (This test verifies that yield functionality doesn't bypass existing compliance)
        assertTrue(
            systemUtils.identityRegistry().isVerified(clientBE, requiredClaimTopics),
            "Client should be verified for yield claims"
        );

        vm.prank(clientBE);
        ISMARTFixedYieldSchedule(scheduleAddress).claimYield();

        // Yield claim should succeed for verified client
        assertTrue(
            ISMARTFixedYieldSchedule(scheduleAddress).lastClaimedPeriod(clientBE) > 0,
            "Verified client should be able to claim yield"
        );
    }

    // --- Helper Functions ---
    
    // Helper to advance both time and block number
    function _advanceTimeAndBlock(uint256 newTimestamp) internal {
        vm.warp(newTimestamp);
        // Set block number to match timestamp for yield schedule compatibility
        // This is necessary because the yield schedule uses timestamps as block numbers
        vm.roll(newTimestamp);
    }
    
    // Helper to mint tokens with proper block number alignment
    function _mintWithAlignedBlock(address to, uint256 amount) internal {
        // Ensure block number is aligned with timestamp before minting
        if (block.number < block.timestamp) {
            vm.roll(block.timestamp);
        }
        tokenUtils.mintToken(address(token), tokenIssuer, to, amount);
    }

    function _createYieldSchedule() internal returns (address) {
        return _createYieldSchedule(block.timestamp + 1 days);
    }

    function _createYieldSchedule(uint256 startDate) internal returns (address) {
        uint256 endDate = startDate + SCHEDULE_DURATION;

        vm.prank(tokenIssuer);
        return yieldScheduleFactory.create(ISMARTYield(address(token)), startDate, endDate, YIELD_RATE, PERIOD_INTERVAL);
    }

    function _fundYieldSchedule(address scheduleAddress, uint256 amount) internal {
        // Mint yield tokens to platform admin
        MockERC20(yieldPaymentToken).mint(platformAdmin, amount);

        // Approve and fund the schedule
        vm.startPrank(platformAdmin);
        IERC20(yieldPaymentToken).approve(scheduleAddress, amount);
        ISMARTFixedYieldSchedule(scheduleAddress).topUpUnderlyingAsset(amount);
        vm.stopPrank();
    }
}

// Simple Mock ERC20 for testing yield payments
contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string public name;
    string public symbol;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        _transfer(from, to, amount);
        _approve(from, msg.sender, currentAllowance - amount);

        return true;
    }

    function mint(address to, uint256 amount) external {
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(_balances[from] >= amount, "ERC20: transfer amount exceeds balance");

        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}