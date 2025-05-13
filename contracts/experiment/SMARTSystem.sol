// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { ERC2771Context, Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { SMARTCompliance } from "./compliance/SMARTCompliance.sol";
import { SMARTComplianceImplementation } from "./compliance/SMARTComplianceImplementation.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SMARTTokenRegistry } from "./tokens-registry/SMARTTokenRegistry.sol";

contract SMARTSystem is ERC2771Context, AccessControl {
    address private _complianceImplementation;
    address private _compliance;
    address private _tokenRegistryImplementation;
    address private _tokenRegistry;

    constructor(address admin, address forwarder) ERC2771Context(forwarder) AccessControl() {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function registerCompliance(address _implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _complianceImplementation = _implementation;
        _compliance = address(new SMARTCompliance(address(this)));
    }

    function compliance() public view returns (address) {
        return _compliance;
    }

    function complianceImplementation() public view returns (address) {
        return address(_complianceImplementation);
    }

    function registerTokenRegistry(address _implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _tokenRegistryImplementation = _implementation;
        _tokenRegistry = address(new SMARTTokenRegistry(address(this)));
    }

    function tokenRegistry() public view returns (address) {
        return _tokenRegistry;
    }

    function tokenRegistryImplementation() public view onlyRole(DEFAULT_ADMIN_ROLE) returns (address) {
        return address(_tokenRegistryImplementation);
    }

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
}
