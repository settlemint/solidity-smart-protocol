// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC2771Context, Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { SMARTBond } from "../bond/SMARTBond.sol";

contract SMARTTokenRegistryImplementation is AccessControl, ERC2771Context {
    address private _bondImplementation;
    address[] private _bonds;

    // would be better via some sort of initialise function
    constructor(address forwarder) ERC2771Context(forwarder) { }

    /// @notice Returns the message sender in the context of meta-transactions
    /// @dev Overrides both Context and ERC2771Context to support meta-transactions
    /// @return The address of the message sender
    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return super._msgSender();
    }

    /// @notice Returns the message data in the context of meta-transactions
    /// @dev Overrides both Context and ERC2771Context to support meta-transactions
    /// @return The message data
    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return super._msgData();
    }

    /// @notice Returns the length of the context suffix for meta-transactions
    /// @dev Overrides both Context and ERC2771Context to support meta-transactions
    /// @return The length of the context suffix
    function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
        return super._contextSuffixLength();
    }

    function createToken() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _bonds.push(address(new SMARTBond(address(this))));
    }

    function registerBond(address bondImplementation_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _bondImplementation = bondImplementation_;
    }

    function bondImplementation() public view returns (address) {
        return address(_bondImplementation);
    }
}
