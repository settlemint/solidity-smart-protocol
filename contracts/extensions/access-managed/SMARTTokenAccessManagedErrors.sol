// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/**
 * @dev The `account` is missing a role.
 * @notice This error is the same as the one defined in `@openzeppelin/contracts/access/AccessControl.sol`.
 */
error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
