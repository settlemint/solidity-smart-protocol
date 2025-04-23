// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SMARTBaseTest } from "./SMARTBaseTest.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

abstract contract SMARTBurnableTest is SMARTBaseTest {
    function test_Burn_Success() public {
        require(address(token) != address(0), "Token not deployed");
        _mintInitialBalances();
        uint256 burnAmount = 100 ether;
        uint256 balBESnap = token.balanceOf(clientBE);
        uint256 hookCountSnap = mockComplianceModule.destroyedCallCount();

        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, burnAmount);

        assertEq(token.balanceOf(clientBE), balBESnap - burnAmount, "Balance wrong after burn");
        assertEq(mockComplianceModule.destroyedCallCount(), hookCountSnap + 1, "Hook count wrong after burn");
    }

    function test_Burn_InsufficientBalance_Reverts() public {
        require(address(token) != address(0), "Token not deployed");
        _mintInitialBalances();
        uint256 senderBalance = token.balanceOf(clientBE);
        uint256 burnAmount = senderBalance + 1 ether;

        // Assuming burn also uses standard ERC20 insufficient balance revert
        // If it has a custom error, adjust this.
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, clientBE, senderBalance, burnAmount)
        );
        tokenUtils.burnToken(address(token), tokenIssuer, clientBE, burnAmount);
    }

    function test_Burn_AccessControl_Reverts() public {
        require(address(token) != address(0), "Token not deployed");
        _mintInitialBalances();
        vm.startPrank(clientBE); // Non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, clientBE));
        tokenUtils.burnTokenAsExecutor(address(token), clientBE, clientBE, 10 ether);
        vm.stopPrank();
    }
}
