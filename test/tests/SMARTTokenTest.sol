// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SMARTBaseTest } from "./SMARTBaseTest.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { ISMARTComplianceModule } from "../../contracts/SMART/interface/ISMARTComplianceModule.sol";
import { ISMART } from "../../contracts/SMART/interface/ISMART.sol";

abstract contract SMARTTokenTest is SMARTBaseTest {
    function test_Mint_Success() public {
        require(address(token) != address(0), "Token not deployed");
        _mintInitialBalances(); // Use helper
        assertEq(token.balanceOf(clientBE), INITIAL_MINT_AMOUNT, "Initial mint failed");
        assertEq(mockComplianceModule.createdCallCount(), 3, "Mock created hook count incorrect after initial mints");
    }

    function test_Mint_AccessControl_Reverts() public {
        require(address(token) != address(0), "Token not deployed");
        vm.startPrank(clientBE); // Non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, clientBE));
        token.mint(clientBE, 100 ether);
        vm.stopPrank();
    }

    function test_Transfer_Success() public {
        require(address(token) != address(0), "Token not deployed");
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

    function test_Transfer_InsufficientBalance_Reverts() public {
        require(address(token) != address(0), "Token not deployed");
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

    function test_Transfer_ToUnverified_Reverts() public {
        require(address(token) != address(0), "Token not deployed");
        _mintInitialBalances();
        uint256 transferAmount = 100 ether;
        uint256 hookCountSnap = mockComplianceModule.transferredCallCount();

        vm.expectRevert(abi.encodeWithSelector(ISMART.RecipientNotVerified.selector));
        tokenUtils.transferToken(address(token), clientBE, clientUnverified, transferAmount);
        assertEq(mockComplianceModule.transferredCallCount(), hookCountSnap, "Hook count changed on verification fail");
    }

    function test_Transfer_MockComplianceBlocked_Reverts() public {
        require(address(token) != address(0), "Token not deployed");
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
}
