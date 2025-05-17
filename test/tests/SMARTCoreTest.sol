// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AbstractSMARTTest } from "./AbstractSMARTTest.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ISMARTComplianceModule } from "../../contracts/interface/ISMARTComplianceModule.sol";
import { ISMART } from "../../contracts/interface/ISMART.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ZeroAddressNotAllowed } from "../../contracts/extensions/common/CommonErrors.sol";
import { CannotRecoverSelf, InsufficientTokenBalance } from "../../contracts/extensions/core/SMARTErrors.sol";
import { TokenRecovered } from "../../contracts/extensions/core/SMARTEvents.sol";
import { MockedERC20Token } from "../utils/mocks/MockedERC20Token.sol";
import { SMARTToken } from "../../contracts/SMARTToken.sol";

abstract contract SMARTCoreTest is AbstractSMARTTest {
    using SafeERC20 for IERC20;

    MockedERC20Token internal mockForeignToken;
    uint256 internal constant FOREIGN_TOKEN_SENT_AMOUNT = 500 ether;

    function _setUpCoreTest() internal virtual /* override */ {
        super.setUp();
        // Ensure token has default collateral set up for core tests
        _setupDefaultCollateralClaim();

        // Deploy and setup mock foreign ERC20 token
        mockForeignToken = new MockedERC20Token("Mock Foreign", "MFT", 6);
        vm.prank(tokenIssuer);
        mockForeignToken.mint(tokenIssuer, 1_000_000 ether);

        // Send some foreign tokens to the main token contract address
        vm.prank(tokenIssuer);
        IERC20(address(mockForeignToken)).safeTransfer(address(token), FOREIGN_TOKEN_SENT_AMOUNT);
        assertEq(mockForeignToken.balanceOf(address(token)), FOREIGN_TOKEN_SENT_AMOUNT, "Foreign token setup failed");
    }

    function test_Core_Mint_Success() public {
        _setUpCoreTest();
        // manual mint, because _mintInitialBalances resets the compliance counter
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, INITIAL_MINT_AMOUNT);
        tokenUtils.mintToken(address(token), tokenIssuer, clientJP, INITIAL_MINT_AMOUNT);
        tokenUtils.mintToken(address(token), tokenIssuer, clientUS, INITIAL_MINT_AMOUNT);

        assertEq(token.balanceOf(clientBE), INITIAL_MINT_AMOUNT, "Initial mint failed");
        assertEq(mockComplianceModule.createdCallCount(), 3, "Mock created hook count incorrect after initial mints");
    }

    function test_Core_Mint_AccessControl_Reverts() public {
        _setUpCoreTest();
        vm.startPrank(clientBE); // Non-owner
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                clientBE,
                SMARTToken(address(token)).MINTER_ROLE()
            )
        );
        token.mint(clientBE, 100 ether);
        vm.stopPrank();
    }

    function test_Core_Transfer_Success() public {
        _setUpCoreTest();
        _mintInitialBalances();
        uint256 transferAmount = 100 ether;
        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 balJPSnap = token.balanceOf(clientJP);
        uint256 hookCountSnap = mockComplianceModule.transferredCallCount();

        tokenUtils.transferToken(address(token), clientBE, clientJP, transferAmount);

        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Receiver balance wrong");
        assertEq(token.balanceOf(clientBE), balBESnap - transferAmount, "Sender balance wrong");
        assertEq(mockComplianceModule.transferredCallCount(), hookCountSnap + 1, "Hook count wrong");
    }

    function test_Core_Transfer_InsufficientBalance_Reverts() public {
        _setUpCoreTest();
        _mintInitialBalances();
        uint256 senderBalance = token.balanceOf(clientBE);
        uint256 transferAmount = senderBalance + 1 ether;

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, clientBE, senderBalance, transferAmount
            )
        );
        tokenUtils.transferToken(address(token), clientBE, clientJP, transferAmount);
    }

    function test_Core_Transfer_ToUnverified_Reverts() public {
        _setUpCoreTest();
        _mintInitialBalances();
        uint256 transferAmount = 100 ether;
        uint256 hookCountSnap = mockComplianceModule.transferredCallCount();

        vm.expectRevert(abi.encodeWithSelector(ISMART.RecipientNotVerified.selector));
        tokenUtils.transferToken(address(token), clientBE, clientUnverified, transferAmount);
        assertEq(mockComplianceModule.transferredCallCount(), hookCountSnap, "Hook count changed on verification fail");
    }

    function test_Core_Transfer_MockComplianceBlocked_Reverts() public {
        _setUpCoreTest();
        _mintInitialBalances();
        uint256 transferAmount = 100 ether;
        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 balUSSnap = token.balanceOf(clientUS);

        mockComplianceModule.setNextTransferShouldFail(true);
        vm.expectRevert(
            abi.encodeWithSelector(ISMARTComplianceModule.ComplianceCheckFailed.selector, "Mocked compliance failure")
        );
        tokenUtils.transferToken(address(token), clientBE, clientUS, transferAmount);
        mockComplianceModule.setNextTransferShouldFail(false);

        assertEq(token.balanceOf(clientUS), balUSSnap, "Receiver balance changed on blocked transfer");
        assertEq(token.balanceOf(clientBE), balBESnap, "Sender balance changed on blocked transfer");
    }

    // ==========================================
    //          recoverERC20 Tests
    // ==========================================

    function test_Core_RecoverERC20_Success() public {
        _setUpCoreTest();
        uint256 amountToRecover = FOREIGN_TOKEN_SENT_AMOUNT / 2;
        address recipient = clientBE;
        uint256 initialContractBalance = mockForeignToken.balanceOf(address(token));
        uint256 initialRecipientBalance = mockForeignToken.balanceOf(recipient);

        tokenUtils.recoverERC20Token(address(token), tokenIssuer, address(mockForeignToken), recipient, amountToRecover);

        assertEq(
            mockForeignToken.balanceOf(address(token)),
            initialContractBalance - amountToRecover,
            "Contract balance after recovery incorrect"
        );
        assertEq(
            mockForeignToken.balanceOf(recipient),
            initialRecipientBalance + amountToRecover,
            "Recipient balance after recovery incorrect"
        );
    }

    function test_Core_RecoverERC20_Unauthorized_Reverts() public {
        _setUpCoreTest();
        uint256 amountToRecover = 100 ether;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                clientJP,
                SMARTToken(address(token)).TOKEN_ADMIN_ROLE()
            )
        );
        tokenUtils.recoverERC20Token(address(token), clientJP, address(mockForeignToken), clientBE, amountToRecover);
    }

    function test_Core_RecoverERC20_RecoverSelf_Reverts() public {
        _setUpCoreTest();
        uint256 amountToRecover = 100 ether;

        vm.expectRevert(abi.encodeWithSelector(CannotRecoverSelf.selector));
        tokenUtils.recoverERC20Token(address(token), tokenIssuer, address(token), clientBE, amountToRecover); // Attempt
            // to recover self
    }

    function test_Core_RecoverERC20_ZeroAddressToken_Reverts() public {
        _setUpCoreTest();
        uint256 amountToRecover = 100 ether;

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressNotAllowed.selector));
        tokenUtils.recoverERC20Token(address(token), tokenIssuer, address(0), clientBE, amountToRecover);
    }

    function test_Core_RecoverERC20_ZeroAddressRecipient_Reverts() public {
        _setUpCoreTest();
        uint256 amountToRecover = 100 ether;

        vm.expectRevert(abi.encodeWithSelector(ZeroAddressNotAllowed.selector));
        tokenUtils.recoverERC20Token(
            address(token), tokenIssuer, address(mockForeignToken), address(0), amountToRecover
        );
    }

    function test_Core_RecoverERC20_InsufficientBalance_Reverts() public {
        _setUpCoreTest();
        uint256 amountToRecover = FOREIGN_TOKEN_SENT_AMOUNT + 1 ether; // More than available

        vm.expectRevert(abi.encodeWithSelector(InsufficientTokenBalance.selector));
        tokenUtils.recoverERC20Token(address(token), tokenIssuer, address(mockForeignToken), clientBE, amountToRecover);
    }

    function test_SupportsInterface_CoreSMART() public {
        _setUpCoreTest(); // Use the specific setup for core tests
        assertTrue(
            IERC165(address(token)).supportsInterface(type(ISMART).interfaceId),
            "Token does not support ISMART interface"
        );
    }
}
