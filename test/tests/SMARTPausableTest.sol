// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SMARTTest } from "./SMARTTest.sol"; // Inherit from the logic base
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { _SMARTPausableLogic } from "../../contracts/extensions/pausable/internal/_SMARTPausableLogic.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { TokenPaused, ExpectedPause } from "../../contracts/extensions/pausable/SMARTPausableErrors.sol";
import { SMARTPausableAccessControlAuthorization } from
    "../../contracts/extensions/pausable/SMARTPausableAccessControlAuthorization.sol";

abstract contract SMARTPausableTest is SMARTTest {
    // Renamed from setUp, removed override
    function _setUpPausableTest() internal /* override */ {
        super.setUp();
        // Ensure token has default collateral set up for pausable tests
        _setupDefaultCollateralClaim();
        _mintInitialBalances();
    }

    function test_Pause_SetAndCheck() public {
        _setUpPausableTest(); // Call setup explicitly
        // Cast to SMARTPausable for view function
        assertFalse(tokenUtils.isPaused(address(token)), "Token should not be paused initially");
        tokenUtils.pauseToken(address(token), tokenIssuer);
        // Cast to SMARTPausable for view function
        assertTrue(tokenUtils.isPaused(address(token)), "Token should be paused");
    }

    function test_Pause_MintWhilePaused_Reverts() public {
        _setUpPausableTest(); // Call setup explicitly
        tokenUtils.pauseToken(address(token), tokenIssuer);
        vm.expectRevert(abi.encodeWithSelector(TokenPaused.selector));
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, 1 ether);
    }

    function test_Pause_TransferWhilePaused_Reverts() public {
        _setUpPausableTest(); // Call setup explicitly
        tokenUtils.pauseToken(address(token), tokenIssuer);
        vm.expectRevert(abi.encodeWithSelector(TokenPaused.selector));
        tokenUtils.transferToken(address(token), clientBE, clientJP, 1 ether);
    }

    function test_Pause_BurnWhilePaused_Reverts() public {
        _setUpPausableTest(); // Call setup explicitly
        tokenUtils.pauseToken(address(token), tokenIssuer);
        vm.expectRevert(abi.encodeWithSelector(TokenPaused.selector));
        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, 1 ether);
    }

    function test_Unpause_SetAndCheck() public {
        _setUpPausableTest(); // Call setup explicitly
        tokenUtils.pauseToken(address(token), tokenIssuer);
        // Cast to SMARTPausable for view function
        assertTrue(tokenUtils.isPaused(address(token)), "Token should be paused before unpause");
        tokenUtils.unpauseToken(address(token), tokenIssuer);
        // Cast to SMARTPausable for view function
        assertFalse(tokenUtils.isPaused(address(token)), "Token should be unpaused");
    }

    function test_Unpause_OperationsAfterUnpause_Succeed() public {
        _setUpPausableTest(); // Call setup explicitly
        tokenUtils.pauseToken(address(token), tokenIssuer);
        tokenUtils.unpauseToken(address(token), tokenIssuer);

        // Mint should work
        uint256 mintAmount = 1 ether;
        uint256 balBESnap = token.balanceOf(clientBE);
        tokenUtils.mintToken(address(token), tokenIssuer, clientBE, mintAmount);
        assertEq(token.balanceOf(clientBE), balBESnap + mintAmount, "Mint after unpause failed");

        // Transfer should work
        uint256 transferAmount = 1 ether;
        balBESnap = token.balanceOf(clientBE);
        uint256 balJPSnap = token.balanceOf(clientJP);
        tokenUtils.transferToken(address(token), clientBE, clientJP, transferAmount);
        assertEq(token.balanceOf(clientBE), balBESnap - transferAmount, "Transfer after unpause failed (sender)");
        assertEq(token.balanceOf(clientJP), balJPSnap + transferAmount, "Transfer after unpause failed (receiver)");

        // Burn should work
        uint256 burnAmount = 1 ether;
        balBESnap = token.balanceOf(clientBE);
        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, burnAmount);
        assertEq(token.balanceOf(clientBE), balBESnap - burnAmount, "Burn after unpause failed");
    }

    function test_Pause_AccessControl_Reverts() public {
        _setUpPausableTest(); // Call setup explicitly
        assertFalse(tokenUtils.isPaused(address(token)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                clientBE,
                SMARTPausableAccessControlAuthorization(address(token)).PAUSER_ROLE()
            )
        );
        tokenUtils.pauseToken(address(token), clientBE);
        assertFalse(tokenUtils.isPaused(address(token)));
    }
}
