// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

import { AbstractSMARTAssetTest } from "./AbstractSMARTAssetTest.sol";
import { MockedERC20Token } from "../utils/mocks/MockedERC20Token.sol";
import { MockedForwarder } from "../utils/mocks/MockedForwarder.sol";
import { ISMARTYield } from "../../contracts/extensions/yield/ISMARTYield.sol";
import { SMARTComplianceModuleParamPair } from "../../contracts/interface/structs/SMARTComplianceModuleParamPair.sol";
import { SMARTBond } from "../../contracts/assets/SMARTBond.sol";
import { SMARTConstants } from "../../contracts/assets/SMARTConstants.sol";
import { SMARTRoles } from "../../contracts/assets/SMARTRoles.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ERC20Capped } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import { SMARTFixedYieldScheduleFactory } from
    "../../contracts/extensions/yield/schedules/fixed/SMARTFixedYieldScheduleFactory.sol";
import { SMARTFixedYieldSchedule } from "../../contracts/extensions/yield/schedules/fixed/SMARTFixedYieldSchedule.sol";
import { InvalidDecimals } from "../../contracts/extensions/core/SMARTErrors.sol";
import { YieldScheduleAlreadySet, YieldScheduleActive } from "../../contracts/extensions/yield/SMARTYieldErrors.sol";

contract SMARTBondTest is AbstractSMARTAssetTest {
    SMARTBond public bond;
    MockedERC20Token public underlyingAsset;

    address public owner;
    address public user1;
    address public user2;
    address public spender;

    uint256 public initialSupply;
    uint256 public faceValue;
    uint256 public initialUnderlyingSupply;
    uint256 public maturityDate;

    uint8 public constant WHOLE_INITIAL_SUPPLY = 100;
    uint8 public constant WHOLE_FACE_FALUE = 100;
    uint8 public constant DECIMALS = 2;
    uint256 public constant CAP = 1000 * 10 ** DECIMALS; // 1000 tokens cap

    // Utility functions for decimal conversions
    function toDecimals(uint256 amount) internal pure returns (uint256) {
        return amount * 10 ** DECIMALS;
    }

    function fromDecimals(uint256 amount) internal pure returns (uint256) {
        return amount / 10 ** DECIMALS;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Paused(address account);
    event Unpaused(address account);
    event BondMatured(uint256 timestamp);
    event UnderlyingAssetTopUp(address indexed from, uint256 amount);
    event BondRedeemed(address indexed holder, uint256 bondAmount, uint256 underlyingAmount);
    event UnderlyingAssetWithdrawn(address indexed to, uint256 amount);

    function setUp() public {
        // Create identities
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        spender = makeAddr("spender");

        // Initialize SMART
        setUpSMART(owner);

        // Initialize identities
        address[] memory identities = new address[](4);
        identities[0] = owner;
        identities[1] = user1;
        identities[2] = user2;
        identities[3] = spender;
        _setUpIdentities(identities);

        maturityDate = block.timestamp + 365 days;

        // Initialize supply and face value using toDecimals
        initialSupply = toDecimals(WHOLE_INITIAL_SUPPLY); // 100.00 bonds
        faceValue = toDecimals(WHOLE_FACE_FALUE); // 100.00 underlying tokens per bond
        initialUnderlyingSupply = initialSupply * faceValue / (10 ** DECIMALS);

        // Deploy mock underlying asset with same decimals
        underlyingAsset = new MockedERC20Token("Mock USD", "MUSD", DECIMALS);
        underlyingAsset.mint(owner, initialUnderlyingSupply); // Mint enough for all bonds

        // Deploy forwarder first
        forwarder = new MockedForwarder();

        bond = _createBondAndMint(
            "Test Bond",
            "TBOND",
            DECIMALS,
            CAP,
            maturityDate,
            faceValue,
            address(underlyingAsset),
            new uint256[](0),
            new SMARTComplianceModuleParamPair[](0)
        );
        vm.label(address(bond), "Bond");
    }

    function _createBondAndMint(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 cap_,
        uint256 maturityDate_,
        uint256 faceValue_,
        address underlyingAsset_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        internal
        returns (SMARTBond result)
    {
        vm.startPrank(owner);
        SMARTBond smartBondImplementation = new SMARTBond(address(forwarder));
        vm.label(address(smartBondImplementation), "Bond Implementation");

        bytes memory data = abi.encodeWithSelector(
            SMARTBond.initialize.selector,
            name_,
            symbol_,
            decimals_,
            cap_,
            maturityDate_,
            faceValue_,
            underlyingAsset_,
            requiredClaimTopics_,
            initialModulePairs_,
            identityRegistry,
            compliance,
            address(accessManager)
        );

        result = SMARTBond(address(new ERC1967Proxy(address(smartBondImplementation), data)));
        vm.label(address(result), "Bond");
        vm.stopPrank();

        _grantAllRoles(owner, owner);

        _createAndSetTokenOnchainID(address(result), owner);

        vm.prank(owner);
        result.mint(owner, initialSupply);

        return result;
    }

    // Basic ERC20 functionality tests
    function test_InitialState() public view {
        assertEq(bond.name(), "Test Bond");
        assertEq(bond.symbol(), "TBOND");
        assertEq(bond.decimals(), DECIMALS);
        assertEq(bond.totalSupply(), initialSupply);
        assertEq(bond.balanceOf(owner), initialSupply);
        assertEq(bond.maturityDate(), maturityDate);
        assertEq(bond.faceValue(), faceValue);
        assertEq(address(bond.underlyingAsset()), address(underlyingAsset));
        assertFalse(bond.isMatured());
        assertTrue(bond.hasRole(SMARTRoles.MINTER_ROLE, owner));
        assertTrue(bond.hasRole(SMARTRoles.TOKEN_ADMIN_ROLE, owner));
    }

    function test_DifferentDecimals() public {
        uint8[] memory decimalValues = new uint8[](4);
        decimalValues[0] = 0; // Test zero decimals
        decimalValues[1] = 6;
        decimalValues[2] = 8;
        decimalValues[3] = 18; // Test max decimals

        for (uint256 i = 0; i < decimalValues.length; ++i) {
            SMARTBond newBond = _createBondAndMint(
                "Test Bond",
                "TBOND",
                decimalValues[i],
                CAP,
                maturityDate,
                faceValue,
                address(underlyingAsset),
                new uint256[](0),
                new SMARTComplianceModuleParamPair[](0)
            );
            assertEq(newBond.decimals(), decimalValues[i]);
        }
    }

    function test_RevertOnInvalidDecimals() public {
        vm.startPrank(owner);
        SMARTBond smartBondImplementation = new SMARTBond(address(forwarder));
        bytes memory data = abi.encodeWithSelector(
            SMARTBond.initialize.selector,
            "Test Bond",
            "TBOND",
            19,
            CAP,
            maturityDate,
            faceValue,
            address(underlyingAsset),
            new uint256[](0),
            new SMARTComplianceModuleParamPair[](0),
            identityRegistry,
            compliance,
            address(accessManager)
        );

        vm.expectRevert(abi.encodeWithSelector(InvalidDecimals.selector, 19));
        SMARTBond(address(new ERC1967Proxy(address(smartBondImplementation), data)));
        vm.stopPrank();
    }

    function test_Transfer() public {
        uint256 amount = toDecimals(10); // 10.00 bonds
        vm.prank(owner);
        bond.transfer(user1, amount);

        assertEq(bond.balanceOf(user1), amount);
        assertEq(bond.balanceOf(owner), initialSupply - amount);
    }

    function test_TransferFrom() public {
        uint256 amount = toDecimals(10); // 10.00 bonds

        // Check initial state
        assertEq(bond.balanceOf(owner), initialSupply, "Initial balance incorrect");
        assertEq(bond.getFrozenTokens(owner), 0, "Should not have frozen tokens");

        vm.startPrank(owner);
        bond.approve(user1, amount);
        vm.stopPrank();

        vm.prank(user1);
        bond.transferFrom(owner, user2, amount);

        assertEq(bond.balanceOf(user2), amount);
        assertEq(bond.balanceOf(owner), initialSupply - amount);
    }

    // Role-based access control tests
    function test_OnlySupplyManagementCanMint() public {
        vm.prank(owner);
        bond.mint(user1, toDecimals(100));
        assertEq(bond.balanceOf(user1), toDecimals(100));

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, SMARTRoles.MINTER_ROLE
            )
        );
        bond.mint(user1, toDecimals(100));
        vm.stopPrank();
    }

    function test_RoleManagement() public {
        vm.startPrank(owner);
        accessManager.grantRole(SMARTRoles.MINTER_ROLE, user1);
        assertTrue(bond.hasRole(SMARTRoles.MINTER_ROLE, user1));

        accessManager.revokeRole(SMARTRoles.MINTER_ROLE, user1);
        assertFalse(bond.hasRole(SMARTRoles.MINTER_ROLE, user1));
        vm.stopPrank();
    }

    // Pausable functionality tests
    function test_PauseUnpause() public {
        vm.startPrank(owner);
        bond.pause();
        assertTrue(bond.paused());

        vm.expectRevert();
        bond.transfer(user1, toDecimals(10)); // 10.00 bonds

        bond.unpause();
        assertFalse(bond.paused());

        bond.transfer(user1, toDecimals(10)); // 10.00 bonds
        assertEq(bond.balanceOf(user1), toDecimals(10));
        vm.stopPrank();
    }

    function test_OnlyAdminCanPause() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, SMARTRoles.PAUSER_ROLE
            )
        );
        bond.pause();
        vm.stopPrank();
        vm.prank(owner);
        bond.pause();
        assertTrue(bond.paused());
    }

    // Burnable functionality tests
    function test_Burn() public {
        uint256 burnAmount = toDecimals(10); // 10.00 bonds

        vm.startPrank(owner);
        bond.transfer(user1, burnAmount);

        assertEq(bond.totalSupply(), initialSupply);
        assertEq(bond.balanceOf(user1), burnAmount);

        bond.burn(user1, burnAmount);

        assertEq(bond.totalSupply(), initialSupply - burnAmount);
        assertEq(bond.balanceOf(user1), 0);
        vm.stopPrank();
    }

    // ERC20Custodian tests
    function test_CustodianFunctionality() public {
        vm.startPrank(owner);
        bond.mint(user1, 100);

        // Freeze all tokens
        bond.freezePartialTokens(user1, 100);
        assertEq(bond.getFrozenTokens(user1), 100);

        // Try to transfer the frozen amount
        vm.stopPrank();

        vm.expectRevert();
        vm.startPrank(user1);
        bond.transfer(user2, 100);

        // Set frozen amount to 0 and verify
        vm.stopPrank();

        vm.startPrank(owner);
        bond.unfreezePartialTokens(user1, 100);
        assertEq(bond.getFrozenTokens(user1), 0);

        // Now transfer should work
        vm.stopPrank();
        vm.startPrank(user1);
        bond.transfer(user2, 100);
        assertEq(bond.balanceOf(user2), 100);
    }

    // Maturity functionality tests
    function test_OnlySupplyManagementCanMature() public {
        vm.warp(maturityDate + 1);

        // Try to mature as non-supply manager
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user1, SMARTRoles.TOKEN_ADMIN_ROLE
            )
        );
        bond.mature();
        vm.stopPrank();

        // Add required underlying assets
        vm.startPrank(owner);
        uint256 requiredAmount = initialUnderlyingSupply;
        underlyingAsset.mint(owner, requiredAmount);
        underlyingAsset.approve(address(bond), requiredAmount);
        underlyingAsset.transfer(address(bond), requiredAmount);

        // Now mature as supply manager
        bond.mature();
        assertTrue(bond.isMatured());
        vm.stopPrank();
    }

    function test_CannotMatureBeforeMaturityDate() public {
        vm.prank(owner);
        vm.expectRevert();
        bond.mature();
    }

    function test_CannotMatureTwice() public {
        vm.warp(maturityDate + 1);

        // Add sufficient underlying assets first
        vm.startPrank(owner);
        underlyingAsset.approve(address(bond), initialUnderlyingSupply);
        underlyingAsset.transfer(address(bond), initialUnderlyingSupply);

        bond.mature();
        vm.expectRevert(SMARTBond.BondAlreadyMatured.selector);
        bond.mature();
        vm.stopPrank();
    }

    function test_CannotMatureWithoutSufficientUnderlying() public {
        vm.warp(maturityDate + 2);
        vm.startPrank(owner);

        // Try to mature without any underlying assets
        vm.expectRevert(SMARTBond.InsufficientUnderlyingBalance.selector);
        bond.mature();

        // Add some underlying assets but not enough
        uint256 requiredAmount = initialUnderlyingSupply;
        uint256 partialAmount = requiredAmount / 2;
        underlyingAsset.mint(owner, partialAmount);
        underlyingAsset.approve(address(bond), partialAmount);
        underlyingAsset.transfer(address(bond), partialAmount);

        // Try to mature with insufficient underlying assets
        vm.expectRevert(SMARTBond.InsufficientUnderlyingBalance.selector);
        bond.mature();

        vm.stopPrank();
    }

    function test_WithdrawReserveAfterPartialRedemption() public {
        // Setup: Add required underlying assets
        uint256 requiredAmount = initialUnderlyingSupply;
        uint256 excessAmount = toDecimals(50);
        uint256 totalAmount = requiredAmount + excessAmount;

        vm.startPrank(owner);
        underlyingAsset.mint(owner, totalAmount); // Mint additional tokens
        underlyingAsset.approve(address(bond), totalAmount);
        underlyingAsset.transfer(address(bond), totalAmount);

        // Transfer some bonds to user1
        uint256 user1Bonds = toDecimals(10);
        bond.transfer(user1, user1Bonds);

        // Mature the bond
        vm.warp(maturityDate + 1);
        bond.mature();
        vm.stopPrank();

        // User1 redeems their bonds
        vm.prank(user1);
        bond.redeem(user1Bonds);

        // Calculate new required reserve after redemption
        uint256 remainingBonds = initialSupply - user1Bonds;
        uint256 newRequiredReserve = remainingBonds * faceValue / (10 ** DECIMALS);

        // Owner should be able to withdraw excess plus freed up reserve
        vm.startPrank(owner);
        uint256 withdrawableAmount = bond.withdrawableUnderlyingAmount();
        bond.recoverERC20(address(underlyingAsset), owner, withdrawableAmount);

        // Verify final state
        assertEq(bond.underlyingAssetBalance(), newRequiredReserve);
        vm.stopPrank();
    }

    function test_WithdrawableAmount() public {
        // Initially no excess
        assertEq(bond.withdrawableUnderlyingAmount(), 0);

        vm.startPrank(owner);

        // Top up with more than needed
        uint256 requiredAmount = initialUnderlyingSupply;
        uint256 excessAmount = toDecimals(5); // 5.00 excess tokens
        uint256 totalAmount = requiredAmount + excessAmount;

        underlyingAsset.mint(owner, totalAmount);
        underlyingAsset.approve(address(bond), totalAmount);
        underlyingAsset.transfer(address(bond), totalAmount);

        assertEq(bond.underlyingAssetBalance(), totalAmount);
        assertEq(bond.totalUnderlyingNeeded(), requiredAmount);

        // Verify withdrawable amount equals excess
        uint256 withdrawable = bond.withdrawableUnderlyingAmount();
        assertEq(withdrawable, excessAmount);

        vm.stopPrank();
    }

    function test_RedeemBonds() public {
        // Setup: Add required underlying assets
        uint256 requiredAmount = initialUnderlyingSupply;
        vm.startPrank(owner);
        underlyingAsset.approve(address(bond), requiredAmount);
        underlyingAsset.transfer(address(bond), requiredAmount);

        // Transfer some bonds to user1
        uint256 user1Bonds = toDecimals(10);
        bond.transfer(user1, user1Bonds);

        // Mature the bond
        vm.warp(maturityDate + 1);
        bond.mature();
        vm.stopPrank();

        // User1 redeems their bonds
        vm.startPrank(user1);
        uint256 expectedUnderlyingAmount = user1Bonds * faceValue / (10 ** DECIMALS);
        bond.redeem(user1Bonds);

        // Verify redemption
        assertEq(bond.balanceOf(user1), 0);
        assertEq(underlyingAsset.balanceOf(user1), expectedUnderlyingAmount);
        vm.stopPrank();
    }

    // Tests for underlying asset management
    function test_TopUpUnderlyingAsset() public {
        uint256 topUpAmount = toDecimals(100);

        vm.startPrank(owner);
        underlyingAsset.approve(address(bond), topUpAmount);
        underlyingAsset.transfer(address(bond), topUpAmount);
        vm.stopPrank();

        assertEq(bond.underlyingAssetBalance(), topUpAmount);
    }

    function test_HistoricalBalances() public {
        uint256 amount = toDecimals(10); // 10.00 bonds

        // Step 1: Initial state - warp to a starting point and deploy
        vm.warp(1000);
        bond = _createBondAndMint(
            "Test Bond",
            "TBOND",
            DECIMALS,
            CAP,
            maturityDate,
            faceValue,
            address(underlyingAsset),
            new uint256[](0),
            new SMARTComplianceModuleParamPair[](0)
        );

        // Move forward one second to query the initial state
        vm.warp(1001);
        assertEq(bond.balanceOfAt(owner, 1000), initialSupply, "Initial owner balance incorrect");
        assertEq(bond.balanceOfAt(user1, 1000), 0, "Initial user1 balance incorrect");

        // Step 2: First transfer - owner sends 10 bonds to user1
        vm.warp(2000);
        vm.prank(owner);
        bond.transfer(user1, amount);

        // Move forward one second to query the state after first transfer
        vm.warp(2001);
        assertEq(bond.balanceOfAt(owner, 2000), initialSupply - amount, "Owner balance after first transfer");
        assertEq(bond.balanceOfAt(user1, 2000), amount, "User1 balance after first transfer");
        assertEq(bond.balanceOfAt(user2, 2000), 0, "User2 balance after first transfer");

        // Step 3: Second transfer - user1 sends 5 bonds to user2
        vm.warp(3000);
        vm.prank(user1);
        bond.transfer(user2, amount / 2);

        // Move forward one second to query the state after second transfer
        vm.warp(3001);
        assertEq(bond.balanceOfAt(owner, 3000), initialSupply - amount, "Owner balance after second transfer");
        assertEq(bond.balanceOfAt(user1, 3000), amount / 2, "User1 balance after second transfer");
        assertEq(bond.balanceOfAt(user2, 3000), amount / 2, "User2 balance after second transfer");

        // Step 4: Check future timestamp returns current balance
        vm.warp(4000);
        assertEq(bond.balanceOfAt(owner, 3999), initialSupply - amount, "Owner balance at future time");
        assertEq(bond.balanceOfAt(user1, 3999), amount / 2, "User1 balance at future time");
        assertEq(bond.balanceOfAt(user2, 3999), amount / 2, "User2 balance at future time");
    }

    function test_HistoricalBalancesWithMultipleTransfers() public {
        uint256 transferAmount = toDecimals(10); // 10.00 bonds
        uint256 halfTransfer = transferAmount / 2; // 5.00 bonds
        uint256 quarterTransfer = transferAmount / 4; // 2.50 bonds

        // Step 1: Initial state - warp to a starting point and redeploy
        vm.warp(1000);
        bond = _createBondAndMint(
            "Test Bond",
            "TBOND",
            DECIMALS,
            CAP,
            maturityDate,
            faceValue,
            address(underlyingAsset),
            new uint256[](0),
            new SMARTComplianceModuleParamPair[](0)
        );

        // Move forward one second to query initial state
        vm.warp(1001);
        assertEq(bond.balanceOfAt(owner, 1000), initialSupply, "Initial owner balance incorrect");
        assertEq(bond.balanceOfAt(user1, 1000), 0, "Initial user1 balance incorrect");
        assertEq(bond.balanceOfAt(user2, 1000), 0, "Initial user2 balance incorrect");

        // Step 2: First transfer at t1 = 2000
        vm.warp(2000);
        vm.prank(owner);
        bond.transfer(user1, transferAmount);

        // Move forward one second to query state after first transfer
        vm.warp(2001);
        assertEq(bond.balanceOfAt(owner, 2000), initialSupply - transferAmount, "Owner balance after first transfer");
        assertEq(bond.balanceOfAt(user1, 2000), transferAmount, "User1 balance after first transfer");
        assertEq(bond.balanceOfAt(user2, 2000), 0, "User2 balance after first transfer");

        // Step 3: Second transfer at t2 = 3000
        vm.warp(3000);
        vm.prank(user1);
        bond.transfer(user2, halfTransfer);

        // Move forward one second to query state after second transfer
        vm.warp(3001);
        assertEq(bond.balanceOfAt(owner, 3000), initialSupply - transferAmount, "Owner balance after second transfer");
        assertEq(bond.balanceOfAt(user1, 3000), halfTransfer, "User1 balance after second transfer");
        assertEq(bond.balanceOfAt(user2, 3000), halfTransfer, "User2 balance after second transfer");

        // Step 4: Third transfer at t3 = 4000
        vm.warp(4000);
        vm.prank(owner);
        bond.transfer(user2, transferAmount);

        // Move forward one second to query state after third transfer
        vm.warp(4001);
        assertEq(
            bond.balanceOfAt(owner, 4000), initialSupply - (transferAmount * 2), "Owner balance after third transfer"
        );
        assertEq(bond.balanceOfAt(user1, 4000), halfTransfer, "User1 balance after third transfer");
        assertEq(bond.balanceOfAt(user2, 4000), halfTransfer + transferAmount, "User2 balance after third transfer");

        // Step 5: Fourth transfer at t4 = 5000
        vm.warp(5000);
        vm.prank(user2);
        bond.transfer(user1, quarterTransfer);

        // Move forward one second to query state after fourth transfer
        vm.warp(5001);
        assertEq(
            bond.balanceOfAt(owner, 5000), initialSupply - (transferAmount * 2), "Owner balance after fourth transfer"
        );
        assertEq(bond.balanceOfAt(user1, 5000), halfTransfer + quarterTransfer, "User1 balance after fourth transfer");
        assertEq(
            bond.balanceOfAt(user2, 5000),
            halfTransfer + transferAmount - quarterTransfer,
            "User2 balance after fourth transfer"
        );
    }

    function test_HistoricalBalancesBeforeFirstTransfer() public {
        // First warp to a starting point and redeploy the contract
        vm.warp(1000);
        bond = _createBondAndMint(
            "Test Bond",
            "TBOND",
            DECIMALS,
            CAP,
            maturityDate,
            faceValue,
            address(underlyingAsset),
            new uint256[](0),
            new SMARTComplianceModuleParamPair[](0)
        );

        // Store deployment time
        uint256 deploymentTime = 1000;

        // Move forward in time
        vm.warp(3000);

        // Check balance at a timestamp before deployment
        uint256 pastTimestamp = deploymentTime - 1;
        assertEq(bond.balanceOfAt(owner, pastTimestamp), 0, "Should return 0 for timestamp before deployment");
        assertEq(bond.balanceOfAt(user1, pastTimestamp), 0, "Should return 0 for timestamp before deployment");

        // Verify balance at deployment time shows initial supply
        assertEq(
            bond.balanceOfAt(owner, deploymentTime),
            initialSupply,
            "Owner balance at deployment should be initial supply"
        );
        assertEq(bond.balanceOfAt(user1, deploymentTime), 0, "User1 balance at deployment should be 0");

        // Verify current balance shows initial supply
        assertEq(bond.balanceOfAt(owner, 2999), initialSupply, "Current owner balance should be initial supply");
        assertEq(bond.balanceOfAt(user1, 2999), 0, "Current user1 balance should be 0");
    }

    // Add new tests for cap functionality
    function test_CapEnforcement() public {
        vm.startPrank(owner);

        // Try to mint tokens that would exceed the cap
        uint256 remainingToCap = CAP - bond.totalSupply();
        uint256 exceedingAmount = remainingToCap + 1;

        vm.expectRevert(
            abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, exceedingAmount + bond.totalSupply(), CAP)
        );
        bond.mint(owner, exceedingAmount);

        // Should be able to mint up to the cap
        bond.mint(owner, remainingToCap);
        assertEq(bond.totalSupply(), CAP, "Total supply should equal cap");

        // Verify can't mint even 1 more token
        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, CAP + 1, CAP));
        bond.mint(owner, 1);

        vm.stopPrank();
    }

    function test_BurnAndRemintUpToCap() public {
        vm.startPrank(owner);

        // Verify initial state
        assertEq(bond.totalSupply(), initialSupply, "Initial supply incorrect");
        assertEq(bond.cap(), CAP, "Cap incorrect");

        // Calculate remaining amount to cap
        uint256 remainingToCap = CAP - initialSupply;

        // Mint up to the cap
        bond.mint(owner, remainingToCap);
        assertEq(bond.totalSupply(), CAP, "Supply should equal cap");

        // Try to mint one more token
        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, CAP + 1, CAP));
        bond.mint(owner, 1);

        vm.stopPrank();
    }

    function test_InitialCapState() public view {
        assertEq(bond.cap(), CAP, "Cap should be set correctly");
        assertTrue(bond.totalSupply() <= CAP, "Initial supply should not exceed cap");
    }

    function test_TransferWithinCap() public {
        uint256 amount = toDecimals(10);

        vm.prank(owner);
        bond.transfer(user1, amount);

        assertEq(bond.totalSupply(), initialSupply, "Total supply should remain unchanged after transfer");
        assertTrue(bond.totalSupply() <= CAP, "Total supply should still be within cap");
    }

    function test_BondYieldScheduleFlow() public {
        // Deploy necessary contracts (using the existing Bond from setUp())
        vm.startPrank(owner);

        // First verify the bond has no yield schedule
        assertEq(bond.yieldSchedule(), address(0), "Bond should have zero yield schedule initially");

        // Create a forwarder for the FixedYield (already in setup)
        // Create a factory to create the FixedYield
        SMARTFixedYieldScheduleFactory factory = new SMARTFixedYieldScheduleFactory(address(forwarder));

        // Setup yield schedule parameters
        uint256 startDate = block.timestamp + 1 days;
        uint256 endDate = startDate + 365 days;
        uint256 yieldRate = 500; // 5% in basis points
        uint256 interval = 30 days;

        // Create the yield schedule for our bond
        // Note: The factory automatically sets up the circular reference by calling bond.setYieldSchedule()
        address yieldScheduleAddr = factory.create(ISMARTYield(address(bond)), startDate, endDate, yieldRate, interval);

        // We need to set the yield schedule manually
        bond.setYieldSchedule(yieldScheduleAddr);

        // Verify the schedule references our bond
        SMARTFixedYieldSchedule yieldSchedule = SMARTFixedYieldSchedule(yieldScheduleAddr);
        assertEq(address(yieldSchedule.token()), address(bond), "FixedYield should reference the bond");

        // Verify the bond references the yield schedule (this was set by the factory)
        assertEq(bond.yieldSchedule(), yieldScheduleAddr, "Bond should reference the yield schedule");

        // Try to change it (should fail)
        vm.expectRevert(YieldScheduleAlreadySet.selector);
        bond.setYieldSchedule(address(0x123));

        vm.stopPrank();
    }

    function test_CannotMintIfYieldScheduleStarted() public {
        // Setup: Deploy factory and create yield schedule linked to the bond
        vm.startPrank(owner);
        SMARTFixedYieldScheduleFactory factory = new SMARTFixedYieldScheduleFactory(address(forwarder));
        uint256 startDate = block.timestamp + 1 days; // Schedule starts in the future
        uint256 endDate = startDate + 365 days;
        uint256 yieldRate = 500; // 5%
        uint256 interval = 30 days;

        address yieldScheduleAddr = factory.create(ISMARTYield(address(bond)), startDate, endDate, yieldRate, interval);

        // We need to set the yield schedule manually
        bond.setYieldSchedule(yieldScheduleAddr);

        // Verify schedule is linked
        assertEq(bond.yieldSchedule(), yieldScheduleAddr);

        // Minting should still be allowed BEFORE the schedule starts
        bond.mint(owner, 1); // Mint 0.01 tokens
        assertEq(bond.totalSupply(), initialSupply + 1);

        // Warp time to AFTER the schedule start date
        vm.warp(startDate + 1);

        // Now, attempt to mint again
        vm.expectRevert(YieldScheduleActive.selector);
        bond.mint(owner, 1);

        // Ensure total supply hasn't changed after the revert
        assertEq(bond.totalSupply(), initialSupply + 1);

        vm.stopPrank();
    }

    function test_BondForceTransfer() public {
        vm.startPrank(owner);
        bond.mint(user1, 1);
        vm.stopPrank();

        vm.startPrank(owner);
        bond.forcedTransfer(user1, user2, 1);
        vm.stopPrank();

        assertEq(bond.balanceOf(user1), 0);
        assertEq(bond.balanceOf(user2), 1);
    }
}
