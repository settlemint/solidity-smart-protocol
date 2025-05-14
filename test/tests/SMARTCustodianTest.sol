// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AbstractSMARTTest } from "./AbstractSMARTTest.sol"; // Inherit from the logic base
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { TestConstants } from "../Constants.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ISMARTCustodian } from "../../contracts/extensions/custodian/ISMARTCustodian.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    SenderAddressFrozen,
    RecipientAddressFrozen,
    FreezeAmountExceedsAvailableBalance,
    InsufficientFrozenTokens,
    NoTokensToRecover,
    RecoveryTargetAddressFrozen
} from "../../contracts/extensions/custodian/SMARTCustodianErrors.sol";
import { SMARTToken } from "../../contracts/SMARTToken.sol";

abstract contract SMARTCustodianTest is AbstractSMARTTest {
    // Renamed from setUp, removed override
    function _setUpCustodianTest() internal /* override */ {
        super.setUp();
        // Ensure token has default collateral set up for custodian tests
        _setupDefaultCollateralClaim();
        _mintInitialBalances();
    }

    // =====================================================================
    //                         ADDRESS FREEZE TESTS
    // =====================================================================

    function test_Custodian_FreezeAddress_SetAndCheck() public {
        _setUpCustodianTest(); // Call setup explicitly
        assertFalse(tokenUtils.isFrozen(address(token), clientBE), "Should not be frozen initially");
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, true);
        assertTrue(tokenUtils.isFrozen(address(token), clientBE), "Should be frozen");
    }

    function test_Custodian_FreezeAddress_TransferFromFrozen_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, true);
        vm.expectRevert(abi.encodeWithSelector(SenderAddressFrozen.selector));
        tokenUtils.transferToken(address(token), clientBE, clientJP, 1 ether);
    }

    function test_Custodian_FreezeAddress_TransferToFrozen_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientJP, true);
        vm.expectRevert(abi.encodeWithSelector(RecipientAddressFrozen.selector));
        tokenUtils.transferToken(address(token), clientBE, clientJP, 1 ether);
    }

    function test_Custodian_FreezeAddress_MintToFrozen_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, true);
        vm.expectRevert(abi.encodeWithSelector(RecipientAddressFrozen.selector));
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 1 ether);
    }

    function test_Custodian_FreezeAddress_RedeemFromFrozen_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, true);
        vm.expectRevert(abi.encodeWithSelector(SenderAddressFrozen.selector));
        tokenUtils.redeemToken(address(token), clientBE, 1 ether);
    }

    function test_Custodian_FreezeAddress_UnfreezeAndCheck() public {
        _setUpCustodianTest(); // Call setup explicitly
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, true);
        assertTrue(tokenUtils.isFrozen(address(token), clientBE), "Should be frozen before unfreeze");
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, false);
        assertFalse(tokenUtils.isFrozen(address(token), clientBE), "Should be unfrozen");
    }

    function test_Custodian_FreezeAddress_OperationsAfterUnfreeze_Succeed() public {
        _setUpCustodianTest(); // Call setup explicitly
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, true);
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, false);

        // Mint should work
        uint256 mintAmount = 1 ether;
        uint256 balBESnapMint = token.balanceOf(clientBE);
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, mintAmount);
        assertEq(token.balanceOf(clientBE), balBESnapMint + mintAmount, "Mint after unfreeze failed");

        // Transfer should work
        uint256 transferAmount = 1 ether;
        uint256 balBESnapTransfer = token.balanceOf(clientBE);
        uint256 balJPSnapTransfer = token.balanceOf(clientJP);
        tokenUtils.transferToken(address(token), clientBE, clientJP, transferAmount);
        assertEq(
            token.balanceOf(clientBE), balBESnapTransfer - transferAmount, "Transfer after unfreeze failed (sender)"
        );
        assertEq(
            token.balanceOf(clientJP), balJPSnapTransfer + transferAmount, "Transfer after unfreeze failed (receiver)"
        );

        // Redeem should work - USE TOKEN UTILS
        uint256 redeemAmount = 1 ether;
        uint256 balBESnapRedeem = token.balanceOf(clientBE);
        // Use tokenUtils which handles prank and casting
        tokenUtils.redeemToken(address(token), clientBE, redeemAmount);
        assertEq(token.balanceOf(clientBE), balBESnapRedeem - redeemAmount, "Redeem after unfreeze failed");
    }

    function test_Custodian_FreezeAddress_AccessControl_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                clientBE,
                SMARTToken(address(token)).FREEZER_ROLE()
            )
        );
        tokenUtils.setAddressFrozenAsExecutor(address(token), clientBE, clientBE, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                clientBE,
                SMARTToken(address(token)).FREEZER_ROLE()
            )
        );
        tokenUtils.setAddressFrozenAsExecutor(address(token), clientBE, clientBE, false);
    }

    // =====================================================================
    //                     PARTIAL TOKEN FREEZE TESTS
    // =====================================================================

    function test_Custodian_PartialFreeze_FreezeAndCheck() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = 100 ether;
        assertEq(tokenUtils.getFrozenTokens(address(token), clientBE), 0, "Should have 0 frozen initially");
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);
        assertEq(tokenUtils.getFrozenTokens(address(token), clientBE), freezeAmount, "Frozen amount incorrect");
    }

    function test_Custodian_PartialFreeze_FreezeMoreThanAvailable_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 currentBalance = token.balanceOf(clientBE);
        uint256 freezeAmount = currentBalance + 1 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                FreezeAmountExceedsAvailableBalance.selector,
                currentBalance, // Available balance (no frozen tokens yet)
                freezeAmount
            )
        );
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);
    }

    function test_Custodian_PartialFreeze_UnfreezeAndCheck() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = 100 ether;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);
        assertEq(
            tokenUtils.getFrozenTokens(address(token), clientBE),
            freezeAmount,
            "Frozen amount incorrect before unfreeze"
        );

        uint256 unfreezeAmount = 50 ether;
        tokenUtils.unfreezePartialTokens(address(token), tokenIssuer, clientBE, unfreezeAmount);
        assertEq(
            tokenUtils.getFrozenTokens(address(token), clientBE),
            freezeAmount - unfreezeAmount,
            "Frozen amount incorrect after unfreeze"
        );
    }

    function test_Custodian_PartialFreeze_UnfreezeMoreThanFrozen_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = 100 ether;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 unfreezeAmount = freezeAmount + 1 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                InsufficientFrozenTokens.selector,
                freezeAmount, // Currently frozen
                unfreezeAmount
            )
        );
        tokenUtils.unfreezePartialTokens(address(token), tokenIssuer, clientBE, unfreezeAmount);
    }

    function test_Custodian_PartialFreeze_TransferLessThanUnfrozen_Succeeds() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 unfrozenBalance = token.balanceOf(clientBE) - freezeAmount;
        uint256 transferAmount = unfrozenBalance / 2;

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 balJPSnap = token.balanceOf(clientJP);
        uint256 frozenSnap = tokenUtils.getFrozenTokens(address(token), clientBE);

        tokenUtils.transferToken(address(token), clientBE, clientJP, transferAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - transferAmount, "Sender balance wrong");
        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Receiver balance wrong");
        assertEq(tokenUtils.getFrozenTokens(address(token), clientBE), frozenSnap, "Frozen amount changed");
    }

    function test_Custodian_PartialFreeze_TransferExactlyUnfrozen_Succeeds() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 unfrozenBalance = token.balanceOf(clientBE) - freezeAmount;
        uint256 transferAmount = unfrozenBalance;

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 balJPSnap = token.balanceOf(clientJP);
        uint256 frozenSnap = tokenUtils.getFrozenTokens(address(token), clientBE);

        tokenUtils.transferToken(address(token), clientBE, clientJP, transferAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - transferAmount, "Sender balance wrong");
        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Receiver balance wrong");
        assertEq(tokenUtils.getFrozenTokens(address(token), clientBE), frozenSnap, "Frozen amount changed");
    }

    function test_Custodian_PartialFreeze_TransferMoreThanUnfrozen_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 unfrozenBalance = token.balanceOf(clientBE) - freezeAmount;
        uint256 transferAmount = unfrozenBalance + 1 ether;

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, clientBE, unfrozenBalance, transferAmount
            )
        );
        tokenUtils.transferToken(address(token), clientBE, clientJP, transferAmount);
    }

    function test_Custodian_PartialFreeze_BurnLessThanUnfrozen_Succeeds() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 unfrozenBalance = token.balanceOf(clientBE) - freezeAmount;
        uint256 burnAmount = unfrozenBalance / 2;

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 frozenSnap = tokenUtils.getFrozenTokens(address(token), clientBE);

        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, burnAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - burnAmount, "Balance wrong after burn");
        assertEq(tokenUtils.getFrozenTokens(address(token), clientBE), frozenSnap, "Frozen amount changed on burn");
    }

    function test_Custodian_PartialFreeze_BurnExactlyUnfrozen_Succeeds() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 unfrozenBalance = token.balanceOf(clientBE) - freezeAmount;
        uint256 burnAmount = unfrozenBalance;

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 frozenSnap = tokenUtils.getFrozenTokens(address(token), clientBE);

        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, burnAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - burnAmount, "Balance wrong after burn");
        assertEq(tokenUtils.getFrozenTokens(address(token), clientBE), frozenSnap, "Frozen amount changed on burn");
    }

    function test_Custodian_PartialFreeze_BurnMoreThanUnfrozen_SucceedsAndUnfreezes() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 totalBalance = token.balanceOf(clientBE);
        uint256 freezeAmount = totalBalance / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 unfrozenBalance = totalBalance - freezeAmount;
        uint256 burnAmount = unfrozenBalance + (freezeAmount / 2); // Burn into frozen tokens
        uint256 expectedUnfreezeAmount = burnAmount - unfrozenBalance;

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 frozenSnap = tokenUtils.getFrozenTokens(address(token), clientBE);

        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, burnAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - burnAmount, "Balance wrong after burn");
        assertEq(
            tokenUtils.getFrozenTokens(address(token), clientBE),
            frozenSnap - expectedUnfreezeAmount,
            "Frozen amount wrong after burn"
        );
    }

    function test_Custodian_PartialFreeze_BurnMoreThanTotal_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 totalBalance = token.balanceOf(clientBE);
        uint256 freezeAmount = totalBalance / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 burnAmount = totalBalance + 1 ether;

        // Should revert based on total balance check before attempting unfreeze logic
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, clientBE, totalBalance, burnAmount)
        );
        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, burnAmount);
    }

    function test_Custodian_PartialFreeze_RedeemLessThanUnfrozen_Succeeds() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 unfrozenBalance = token.balanceOf(clientBE) - freezeAmount;
        uint256 redeemAmount = unfrozenBalance / 2;

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 frozenSnap = tokenUtils.getFrozenTokens(address(token), clientBE);

        // USE TOKEN UTILS for success case
        tokenUtils.redeemToken(address(token), clientBE, redeemAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - redeemAmount, "Balance wrong after redeem");
        assertEq(tokenUtils.getFrozenTokens(address(token), clientBE), frozenSnap, "Frozen amount changed on redeem");
    }

    function test_Custodian_PartialFreeze_RedeemMoreThanUnfrozen_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 unfrozenBalance = token.balanceOf(clientBE) - freezeAmount;
        uint256 redeemAmount = unfrozenBalance + 1 ether;

        // Redeem checks available *unfrozen* balance - direct call needed for revert test
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, clientBE, unfrozenBalance, redeemAmount
            )
        );
        tokenUtils.redeemToken(address(token), clientBE, redeemAmount);
    }

    function test_Custodian_PartialFreeze_AccessControl_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                clientBE,
                SMARTToken(address(token)).FREEZER_ROLE()
            )
        );
        tokenUtils.freezePartialTokensAsExecutor(address(token), clientBE, clientBE, 1 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                clientBE,
                SMARTToken(address(token)).FREEZER_ROLE()
            )
        );
        tokenUtils.unfreezePartialTokensAsExecutor(address(token), clientBE, clientBE, 1 ether);
        vm.stopPrank();
    }

    // =====================================================================
    //                      FORCED TRANSFER TESTS
    // =====================================================================

    function test_Custodian_ForcedTransfer_Success() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 transferAmount = 100 ether;
        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 balJPSnap = token.balanceOf(clientJP);

        tokenUtils.forcedTransfer(address(token), tokenIssuer, clientBE, clientJP, transferAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - transferAmount, "Sender balance wrong");
        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Receiver balance wrong");
    }

    function test_Custodian_ForcedTransfer_InsufficientTotalBalance_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 currentSenderBalance = token.balanceOf(clientBE);
        uint256 excessiveAmount = currentSenderBalance + 1 wei;

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, clientBE, currentSenderBalance, excessiveAmount
            )
        );
        tokenUtils.forcedTransfer(address(token), tokenIssuer, clientBE, clientJP, excessiveAmount);
    }

    function test_Custodian_ForcedTransfer_FromFrozenSender_Succeeds() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 transferAmount = 10 ether;
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientBE, true);
        assertTrue(tokenUtils.isFrozen(address(token), clientBE), "Sender should be frozen");

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 balJPSnap = token.balanceOf(clientJP);

        tokenUtils.forcedTransfer(address(token), tokenIssuer, clientBE, clientJP, transferAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - transferAmount, "Sender balance wrong");
        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Receiver balance wrong");
        assertTrue(tokenUtils.isFrozen(address(token), clientBE), "Sender should still be frozen");
    }

    function test_Custodian_ForcedTransfer_ToFrozenReceiver_Succeeds() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 transferAmount = 10 ether;
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, clientJP, true);
        assertTrue(tokenUtils.isFrozen(address(token), clientJP), "Receiver should be frozen");

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 balJPSnap = token.balanceOf(clientJP);

        tokenUtils.forcedTransfer(address(token), tokenIssuer, clientBE, clientJP, transferAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - transferAmount, "Sender balance wrong");
        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Receiver balance wrong");
        assertTrue(tokenUtils.isFrozen(address(token), clientJP), "Receiver should still be frozen");
    }

    // --- Forced Transfer with Partial Freeze Scenarios ---

    function test_Custodian_ForcedTransfer_PartialFreeze_LessThanUnfrozen_Succeeds() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 currentFrozen = tokenUtils.getFrozenTokens(address(token), clientBE);
        uint256 currentUnfrozen = token.balanceOf(clientBE) - currentFrozen;
        uint256 transferAmount = currentUnfrozen / 2;

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 balJPSnap = token.balanceOf(clientJP);

        tokenUtils.forcedTransfer(address(token), tokenIssuer, clientBE, clientJP, transferAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - transferAmount, "Sender balance wrong");
        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Receiver balance wrong");
        assertEq(tokenUtils.getFrozenTokens(address(token), clientBE), currentFrozen, "Frozen amount changed");
    }

    function test_Custodian_ForcedTransfer_PartialFreeze_ExactlyUnfrozen_Succeeds() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 currentFrozen = tokenUtils.getFrozenTokens(address(token), clientBE);
        uint256 currentUnfrozen = token.balanceOf(clientBE) - currentFrozen;
        uint256 transferAmount = currentUnfrozen;

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 balJPSnap = token.balanceOf(clientJP);

        tokenUtils.forcedTransfer(address(token), tokenIssuer, clientBE, clientJP, transferAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - transferAmount, "Sender balance wrong");
        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Receiver balance wrong");
        assertEq(tokenUtils.getFrozenTokens(address(token), clientBE), currentFrozen, "Frozen amount changed");
    }

    function test_Custodian_ForcedTransfer_PartialFreeze_MoreThanUnfrozen_SucceedsAndUnfreezes() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        uint256 currentFrozen = tokenUtils.getFrozenTokens(address(token), clientBE);
        uint256 currentUnfrozen = token.balanceOf(clientBE) - currentFrozen;
        uint256 transferAmount = currentUnfrozen + (currentFrozen / 2); // Transfer into frozen
        uint256 expectedUnfreezeAmount = transferAmount - currentUnfrozen;

        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 balJPSnap = token.balanceOf(clientJP);
        uint256 frozenSnap = tokenUtils.getFrozenTokens(address(token), clientBE);

        tokenUtils.forcedTransfer(address(token), tokenIssuer, clientBE, clientJP, transferAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - transferAmount, "Sender balance wrong");
        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Receiver balance wrong");
        assertEq(
            tokenUtils.getFrozenTokens(address(token), clientBE),
            frozenSnap - expectedUnfreezeAmount,
            "Frozen amount wrong"
        );
    }

    function test_Custodian_ForcedTransfer_PartialFreeze_ExactlyRemainingBalance_SucceedsAndUnfreezes() public {
        _setUpCustodianTest(); // Call setup explicitly
        uint256 freezeAmount = token.balanceOf(clientBE) / 2;
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, clientBE, freezeAmount);

        // Perform a small transfer first to make remaining balance different from initial frozen
        uint256 initialUnfrozen = token.balanceOf(clientBE) - freezeAmount;
        if (initialUnfrozen > 0) {
            tokenUtils.forcedTransfer(address(token), tokenIssuer, clientBE, clientJP, initialUnfrozen / 2);
        }

        uint256 remainingBalance = token.balanceOf(clientBE);
        uint256 frozenBeforeFinal = tokenUtils.getFrozenTokens(address(token), clientBE);
        require(remainingBalance >= frozenBeforeFinal, "Invariant broken: balance less than frozen");
        // This test covers the case where the transfer amount equals the total remaining balance,
        // which might require unfreezing part or all of the frozen amount.
        uint256 transferAmount = remainingBalance;
        uint256 expectedUnfreezeAmount = 0;
        uint256 unfrozenBeforeFinal = remainingBalance - frozenBeforeFinal;
        if (transferAmount > unfrozenBeforeFinal) {
            expectedUnfreezeAmount = transferAmount - unfrozenBeforeFinal;
        }

        uint256 balJPSnap = token.balanceOf(clientJP);

        tokenUtils.forcedTransfer(address(token), tokenIssuer, clientBE, clientJP, transferAmount);

        assertEq(token.balanceOf(clientBE), 0, "Sender balance should be 0");
        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Receiver balance wrong");
        assertEq(
            tokenUtils.getFrozenTokens(address(token), clientBE),
            frozenBeforeFinal - expectedUnfreezeAmount,
            "Frozen amount wrong"
        );
    }

    function test_Custodian_ForcedTransfer_AccessControl_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                clientBE,
                SMARTToken(address(token)).FORCED_TRANSFER_ROLE()
            )
        );
        tokenUtils.forcedTransferAsExecutor(address(token), clientBE, clientBE, clientJP, 1 ether);
    }

    // =====================================================================
    //                       ADDRESS RECOVERY TESTS
    // =====================================================================

    function test_Custodian_AddressRecovery_Success() public {
        _setUpCustodianTest(); // Call setup explicitly
        address lostWallet = clientBE;
        address newWallet = makeAddr("New Wallet BE");
        address investorOnchainID = identityUtils.getIdentity(lostWallet);
        require(investorOnchainID != address(0), "Could not get OnchainID");

        uint256 initialLostBalance = token.balanceOf(lostWallet);
        require(initialLostBalance > 0, "Lost wallet has no balance");

        // Perform Recovery
        tokenUtils.recoveryAddress(address(token), tokenIssuer, lostWallet, newWallet, investorOnchainID);

        // Post-checks
        assertEq(token.balanceOf(lostWallet), 0, "Lost wallet balance not zero");
        assertEq(token.balanceOf(newWallet), initialLostBalance, "New wallet balance wrong");
        assertTrue(
            infrastructureUtils.identityRegistry().isVerified(newWallet, requiredClaimTopics),
            "New wallet not verified after recovery"
        );
        assertEq(
            infrastructureUtils.identityRegistry().investorCountry(newWallet),
            TestConstants.COUNTRY_CODE_BE,
            "Country code wrong"
        );
    }

    function test_Custodian_AddressRecovery_WithFrozenState_Success() public {
        _setUpCustodianTest(); // Call setup explicitly
        address lostWallet = clientJP;
        address newWallet = makeAddr("New Wallet JP");
        address investorOnchainID = identityUtils.getIdentity(lostWallet);
        require(investorOnchainID != address(0), "Could not get OnchainID");

        uint256 initialLostBalance = token.balanceOf(lostWallet);
        require(initialLostBalance > 0, "Lost wallet has no balance");

        // Freeze the lost wallet address and some tokens
        uint256 freezeAmount = initialLostBalance / 3;
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, lostWallet, true);
        tokenUtils.freezePartialTokens(address(token), tokenIssuer, lostWallet, freezeAmount);
        assertTrue(tokenUtils.isFrozen(address(token), lostWallet), "Lost wallet not frozen before recovery");
        assertEq(
            tokenUtils.getFrozenTokens(address(token), lostWallet), freezeAmount, "Lost wallet frozen tokens wrong"
        );

        tokenUtils.recoveryAddressAsExecutor(address(token), tokenIssuer, lostWallet, newWallet, investorOnchainID);

        // Post-checks
        assertEq(token.balanceOf(lostWallet), 0, "Lost wallet balance not zero");
        assertEq(token.balanceOf(newWallet), initialLostBalance, "New wallet balance wrong");
        assertTrue(tokenUtils.isFrozen(address(token), newWallet), "New wallet not frozen after recovery");
        assertFalse(tokenUtils.isFrozen(address(token), lostWallet), "Lost wallet still frozen after recovery");
        assertEq(tokenUtils.getFrozenTokens(address(token), newWallet), freezeAmount, "New wallet frozen tokens wrong");
        assertEq(tokenUtils.getFrozenTokens(address(token), lostWallet), 0, "Lost wallet frozen tokens not zero");
        assertTrue(
            infrastructureUtils.identityRegistry().isVerified(newWallet, requiredClaimTopics), "New wallet not verified"
        );
    }

    function test_Custodian_AddressRecovery_NoBalance_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        address lostWallet = clientBE;
        address newWallet = makeAddr("New Wallet BE");
        address investorOnchainID = identityUtils.getIdentity(lostWallet);

        // Burn all balance
        uint256 currentBalance = token.balanceOf(lostWallet);
        if (currentBalance > 0) {
            tokenUtils.burnToken(address(token), tokenIssuer, lostWallet, currentBalance);
        }
        assertEq(token.balanceOf(lostWallet), 0, "Failed to burn balance for test setup");

        vm.expectRevert(abi.encodeWithSelector(NoTokensToRecover.selector));
        tokenUtils.recoveryAddress(address(token), tokenIssuer, lostWallet, newWallet, investorOnchainID);
    }

    function test_Custodian_AddressRecovery_NewWalletFrozen_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        address lostWallet = clientBE;
        address newWallet = makeAddr("New Wallet BE");
        address investorOnchainID = identityUtils.getIdentity(lostWallet);

        // Register new wallet ID and freeze it
        identityUtils.createClientIdentity(newWallet, TestConstants.COUNTRY_CODE_BE);
        tokenUtils.setAddressFrozen(address(token), tokenIssuer, newWallet, true);

        vm.expectRevert(abi.encodeWithSelector(RecoveryTargetAddressFrozen.selector));
        tokenUtils.recoveryAddress(address(token), tokenIssuer, lostWallet, newWallet, investorOnchainID);
    }

    function test_Custodian_AddressRecovery_AccessControl_Reverts() public {
        _setUpCustodianTest(); // Call setup explicitly
        address lostWallet = clientBE;
        address newWallet = makeAddr("New Wallet BE");
        address investorOnchainID = identityUtils.getIdentity(lostWallet);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                clientJP,
                SMARTToken(address(token)).RECOVERY_ROLE()
            )
        );
        tokenUtils.recoveryAddressAsExecutor(address(token), clientJP, clientJP, newWallet, investorOnchainID);
    }

    function test_SupportsInterface_Custodian() public {
        _setUpCustodianTest(); // Use the specific setup for custodian tests
        assertTrue(
            IERC165(address(token)).supportsInterface(type(ISMARTCustodian).interfaceId),
            "Token does not support ISMARTCustodian interface"
        );
    }
}
