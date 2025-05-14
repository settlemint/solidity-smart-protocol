// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

interface ISMARTTokenAccessManaged {
    function hasRole(bytes32 role, address account) external view returns (bool);
}
