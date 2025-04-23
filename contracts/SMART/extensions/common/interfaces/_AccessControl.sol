// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

abstract contract _AccessControl {
    function hasRole(bytes32 role, address account) public view virtual returns (bool);
}
