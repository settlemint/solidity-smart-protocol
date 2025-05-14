// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @title Interface for the SMART Token Access Control Manager
/// @notice Defines the public authorization functions that a token contract can call
///         to delegate access control checks.
interface ISMARTTokenAccessManager {
    function hasRole(bytes32 role, address account) external view returns (bool);
}
