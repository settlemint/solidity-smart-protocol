// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @title Interface for the SMART Token Access Control Manager
/// @notice Defines the public authorization functions that a token contract can call
///         to delegate access control checks.
interface ISMARTTokenAccessManager {
    function hasRole(bytes32 role, address account) external view returns (bool);

    /// @notice Grants `role` to each address in `accounts`.
    /// @param role The role identifier to grant.
    /// @param accounts The addresses that will receive the role.
    function batchGrantRole(bytes32 role, address[] calldata accounts) external;

    /// @notice Revokes `role` from each address in `accounts`.
    /// @param role The role identifier to revoke.
    /// @param accounts The addresses that will lose the role.
    function batchRevokeRole(bytes32 role, address[] calldata accounts) external;
}
