// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { ERC2771Context, Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ISMARTSystem } from "./ISMARTSystem.sol";
import {
    ComplianceImplementationNotSet,
    IdentityRegistryImplementationNotSet,
    IdentityRegistryStorageImplementationNotSet,
    TrustedIssuersRegistryImplementationNotSet,
    IdentityFactoryImplementationNotSet
} from "./SMARTSystemErrors.sol";

import { SMARTComplianceProxy } from "./compliance/SMARTComplianceProxy.sol";
import { SMARTIdentityRegistryProxy } from "./identity-registry/SMARTIdentityRegistryProxy.sol";
import { SMARTIdentityRegistryStorageProxy } from "./identity-registry-storage/SMARTIdentityRegistryStorageProxy.sol";
import { SMARTTrustedIssuersRegistryProxy } from "./trusted-issuers-registry/SMARTTrustedIssuersRegistryProxy.sol";
import { SMARTIdentityFactoryProxy } from "./identity-factory/SMARTIdentityFactoryProxy.sol";

contract SMARTSystem is ISMARTSystem, ERC2771Context, AccessControl {
    address private _complianceImplementation;
    address private _complianceProxy;

    address private _identityRegistryImplementation;
    address private _identityRegistryProxy;

    address private _identityRegistryStorageImplementation;
    address private _identityRegistryStorageProxy;

    address private _trustedIssuersRegistryImplementation;
    address private _trustedIssuersRegistryProxy;

    address private _identityFactoryImplementation;
    address private _identityFactoryProxy;

    constructor(
        address complianceImplementation_,
        address identityRegistryImplementation_,
        address identityRegistryStorageImplementation_,
        address trustedIssuersRegistryImplementation_,
        address identityFactoryImplementation_,
        address forwarder_
    )
        ERC2771Context(forwarder_)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _complianceImplementation = complianceImplementation_;
        _identityRegistryImplementation = identityRegistryImplementation_;
        _identityRegistryStorageImplementation = identityRegistryStorageImplementation_;
        _trustedIssuersRegistryImplementation = trustedIssuersRegistryImplementation_;
        _identityFactoryImplementation = identityFactoryImplementation_;
    }

    function bootstrap() public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_complianceImplementation == address(0)) {
            revert ComplianceImplementationNotSet();
        }
        if (_identityRegistryImplementation == address(0)) {
            revert IdentityRegistryImplementationNotSet();
        }
        if (_identityRegistryStorageImplementation == address(0)) {
            revert IdentityRegistryStorageImplementationNotSet();
        }
        if (_trustedIssuersRegistryImplementation == address(0)) {
            revert TrustedIssuersRegistryImplementationNotSet();
        }
        if (_identityFactoryImplementation == address(0)) {
            revert IdentityFactoryImplementationNotSet();
        }

        _complianceProxy = address(new SMARTComplianceProxy(address(this)));
        _identityRegistryProxy = address(new SMARTIdentityRegistryProxy(address(this)));
        _identityRegistryStorageProxy = address(new SMARTIdentityRegistryStorageProxy(address(this)));
        _trustedIssuersRegistryProxy = address(new SMARTTrustedIssuersRegistryProxy(address(this)));
        _identityFactoryProxy = address(new SMARTIdentityFactoryProxy(address(this)));
    }

    function setComplianceImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _complianceImplementation = implementation;
    }

    function setIdentityRegistryImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _identityRegistryImplementation = implementation;
    }

    function setIdentityRegistryStorageImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _identityRegistryStorageImplementation = implementation;
    }

    function setTrustedIssuersRegistryImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _trustedIssuersRegistryImplementation = implementation;
    }

    function setIdentityFactoryImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _identityFactoryImplementation = implementation;
    }

    function complianceImplementation() public view returns (address) {
        return _complianceImplementation;
    }

    function identityRegistryImplementation() public view returns (address) {
        return _identityRegistryImplementation;
    }

    function identityRegistryStorageImplementation() public view returns (address) {
        return _identityRegistryStorageImplementation;
    }

    function trustedIssuersRegistryImplementation() public view returns (address) {
        return _trustedIssuersRegistryImplementation;
    }

    function identityFactoryImplementation() public view returns (address) {
        return _identityFactoryImplementation;
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
