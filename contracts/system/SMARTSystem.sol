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
    IdentityFactoryImplementationNotSet,
    IdentityImplementationNotSet,
    TokenIdentityImplementationNotSet
} from "./SMARTSystemErrors.sol";

// Interface imports
import { IERC3643IdentityRegistryStorage } from "./../interface/ERC-3643/IERC3643IdentityRegistryStorage.sol";

import { SMARTComplianceProxy } from "./compliance/SMARTComplianceProxy.sol";
import { SMARTIdentityRegistryProxy } from "./identity-registry/SMARTIdentityRegistryProxy.sol";
import { SMARTIdentityRegistryStorageProxy } from "./identity-registry-storage/SMARTIdentityRegistryStorageProxy.sol";
import { SMARTTrustedIssuersRegistryProxy } from "./trusted-issuers-registry/SMARTTrustedIssuersRegistryProxy.sol";
import { SMARTIdentityFactoryProxy } from "./identity-factory/SMARTIdentityFactoryProxy.sol";

/// @title SMARTSystem Contract
/// @notice Main contract for managing the SMART Protocol system components and their implementations.
/// @dev This contract handles the deployment and upgrades of various modules like Compliance, Identity Registry, etc.
/// It uses ERC2771Context for meta-transaction support and AccessControl for role-based permissions.
contract SMARTSystem is ISMARTSystem, ERC2771Context, AccessControl {
    // --- Events ---

    /// @notice Emitted when the compliance module implementation is updated.
    /// @param newImplementation The address of the new compliance module implementation.
    event ComplianceImplementationUpdated(address indexed newImplementation);
    /// @notice Emitted when the identity registry module implementation is updated.
    /// @param newImplementation The address of the new identity registry module implementation.
    event IdentityRegistryImplementationUpdated(address indexed newImplementation);
    /// @notice Emitted when the identity registry storage module implementation is updated.
    /// @param newImplementation The address of the new identity registry storage module implementation.
    event IdentityRegistryStorageImplementationUpdated(address indexed newImplementation);
    /// @notice Emitted when the trusted issuers registry module implementation is updated.
    /// @param newImplementation The address of the new trusted issuers registry module implementation.
    event TrustedIssuersRegistryImplementationUpdated(address indexed newImplementation);
    /// @notice Emitted when the identity factory module implementation is updated.
    /// @param newImplementation The address of the new identity factory module implementation.
    event IdentityFactoryImplementationUpdated(address indexed newImplementation);
    /// @notice Emitted when the investor identity module implementation is updated.
    /// @param newImplementation The address of the new investor identity module implementation.
    event IdentityImplementationUpdated(address indexed newImplementation);
    /// @notice Emitted when the token identity module implementation is updated.
    /// @param newImplementation The address of the new token identity module implementation.
    event TokenIdentityImplementationUpdated(address indexed newImplementation);
    /// @notice Emitted when the system has been bootstrapped, creating proxy contracts for all modules.
    /// @param complianceProxy The address of the deployed SMARTComplianceProxy.
    /// @param identityRegistryProxy The address of the deployed SMARTIdentityRegistryProxy.
    /// @param identityRegistryStorageProxy The address of the deployed SMARTIdentityRegistryStorageProxy.
    /// @param trustedIssuersRegistryProxy The address of the deployed SMARTTrustedIssuersRegistryProxy.
    /// @param identityFactoryProxy The address of the deployed SMARTIdentityFactoryProxy.
    event Bootstrapped(
        address complianceProxy,
        address identityRegistryProxy,
        address identityRegistryStorageProxy,
        address trustedIssuersRegistryProxy,
        address identityFactoryProxy
    );

    // --- State Variables ---

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

    address private _identityImplementation;
    address private _tokenIdentityImplementation;

    // --- Constructor ---

    /// @notice Constructor for the SMARTSystem contract.
    /// @param initialAdmin_ The address of the initial administrator (DEFAULT_ADMIN_ROLE).
    /// @param complianceImplementation_ The initial address of the compliance module implementation.
    /// @param identityRegistryImplementation_ The initial address of the identity registry module implementation.
    /// @param identityRegistryStorageImplementation_ The initial address of the identity registry storage module
    /// implementation.
    /// @param trustedIssuersRegistryImplementation_ The initial address of the trusted issuers registry module
    /// implementation.
    /// @param identityFactoryImplementation_ The initial address of the identity factory module implementation.
    /// @param identityImplementation_ The initial address of the investor identity module implementation.
    /// @param tokenIdentityImplementation_ The initial address of the token identity module implementation.
    /// @param forwarder_ The address of the trusted forwarder for meta-transactions (ERC2771).
    constructor(
        address initialAdmin_,
        address complianceImplementation_,
        address identityRegistryImplementation_,
        address identityRegistryStorageImplementation_,
        address trustedIssuersRegistryImplementation_,
        address identityFactoryImplementation_,
        address identityImplementation_,
        address tokenIdentityImplementation_,
        address forwarder_
    )
        payable
        ERC2771Context(forwarder_)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin_);

        if (complianceImplementation_ == address(0)) revert ComplianceImplementationNotSet();
        if (identityRegistryImplementation_ == address(0)) revert IdentityRegistryImplementationNotSet();
        if (identityRegistryStorageImplementation_ == address(0)) {
            revert IdentityRegistryStorageImplementationNotSet();
        }
        if (trustedIssuersRegistryImplementation_ == address(0)) {
            revert TrustedIssuersRegistryImplementationNotSet();
        }
        if (identityFactoryImplementation_ == address(0)) revert IdentityFactoryImplementationNotSet();
        if (identityImplementation_ == address(0)) revert IdentityImplementationNotSet();
        if (tokenIdentityImplementation_ == address(0)) revert TokenIdentityImplementationNotSet();

        _complianceImplementation = complianceImplementation_;
        _identityRegistryImplementation = identityRegistryImplementation_;
        _identityRegistryStorageImplementation = identityRegistryStorageImplementation_;
        _trustedIssuersRegistryImplementation = trustedIssuersRegistryImplementation_;
        _identityFactoryImplementation = identityFactoryImplementation_;
        _identityImplementation = identityImplementation_;
        _tokenIdentityImplementation = tokenIdentityImplementation_;
    }

    // --- Bootstrap Function ---

    /// @notice Bootstraps the system by deploying proxy contracts for all modules.
    /// @dev This function can only be called by an address with the DEFAULT_ADMIN_ROLE.
    /// @dev Reverts if any of the module implementations are not set (address(0)).
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

        address initialAdmin = _msgSender();

        _complianceProxy = address(new SMARTComplianceProxy(address(this)));
        _identityRegistryStorageProxy = address(new SMARTIdentityRegistryStorageProxy(address(this), initialAdmin));
        _trustedIssuersRegistryProxy = address(new SMARTTrustedIssuersRegistryProxy(address(this), initialAdmin));
        _identityRegistryProxy = address(
            new SMARTIdentityRegistryProxy(
                address(this), initialAdmin, _identityRegistryStorageProxy, _trustedIssuersRegistryProxy
            )
        );
        _identityFactoryProxy = address(new SMARTIdentityFactoryProxy(address(this), initialAdmin));

        // Bind Registry to Storage
        IERC3643IdentityRegistryStorage(_identityRegistryStorageProxy).bindIdentityRegistry(
            address(_identityRegistryProxy)
        );

        emit Bootstrapped(
            _complianceProxy,
            _identityRegistryProxy,
            _identityRegistryStorageProxy,
            _trustedIssuersRegistryProxy,
            _identityFactoryProxy
        );
    }

    // --- Implementation Setter Functions ---

    /// @notice Sets the implementation address for the compliance module.
    /// @dev This function can only be called by an address with the DEFAULT_ADMIN_ROLE.
    /// @param implementation The new address of the compliance module implementation.
    function setComplianceImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _complianceImplementation = implementation;
        emit ComplianceImplementationUpdated(implementation);
    }

    /// @notice Sets the implementation address for the identity registry module.
    /// @dev This function can only be called by an address with the DEFAULT_ADMIN_ROLE.
    /// @param implementation The new address of the identity registry module implementation.
    function setIdentityRegistryImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _identityRegistryImplementation = implementation;
        emit IdentityRegistryImplementationUpdated(implementation);
    }

    /// @notice Sets the implementation address for the identity registry storage module.
    /// @dev This function can only be called by an address with the DEFAULT_ADMIN_ROLE.
    /// @param implementation The new address of the identity registry storage module implementation.
    function setIdentityRegistryStorageImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _identityRegistryStorageImplementation = implementation;
        emit IdentityRegistryStorageImplementationUpdated(implementation);
    }

    /// @notice Sets the implementation address for the trusted issuers registry module.
    /// @dev This function can only be called by an address with the DEFAULT_ADMIN_ROLE.
    /// @param implementation The new address of the trusted issuers registry module implementation.
    function setTrustedIssuersRegistryImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _trustedIssuersRegistryImplementation = implementation;
        emit TrustedIssuersRegistryImplementationUpdated(implementation);
    }

    /// @notice Sets the implementation address for the identity factory module.
    /// @dev This function can only be called by an address with the DEFAULT_ADMIN_ROLE.
    /// @param implementation The new address of the identity factory module implementation.
    function setIdentityFactoryImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _identityFactoryImplementation = implementation;
        emit IdentityFactoryImplementationUpdated(implementation);
    }

    /// @notice Sets the implementation address for the investor identity module.
    /// @dev This function can only be called by an address with the DEFAULT_ADMIN_ROLE.
    /// @param implementation The new address of the investor identity module implementation.
    function setIdentityImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (implementation == address(0)) revert IdentityImplementationNotSet();
        _identityImplementation = implementation;
        emit IdentityImplementationUpdated(implementation);
    }

    /// @notice Sets the implementation address for the token identity module.
    /// @dev This function can only be called by an address with the DEFAULT_ADMIN_ROLE.
    /// @param implementation The new address of the token identity module implementation.
    function setTokenIdentityImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (implementation == address(0)) revert TokenIdentityImplementationNotSet();
        _tokenIdentityImplementation = implementation;
        emit TokenIdentityImplementationUpdated(implementation);
    }

    // --- Implementation Getter Functions ---

    /// @notice Retrieves the current implementation address for the compliance module.
    /// @return address The current address of the compliance module implementation.
    function complianceImplementation() public view returns (address) {
        return _complianceImplementation;
    }

    /// @notice Retrieves the current implementation address for the identity registry module.
    /// @return address The current address of the identity registry module implementation.
    function identityRegistryImplementation() public view returns (address) {
        return _identityRegistryImplementation;
    }

    /// @notice Retrieves the current implementation address for the identity registry storage module.
    /// @return address The current address of the identity registry storage module implementation.
    function identityRegistryStorageImplementation() public view returns (address) {
        return _identityRegistryStorageImplementation;
    }

    /// @notice Retrieves the current implementation address for the trusted issuers registry module.
    /// @return address The current address of the trusted issuers registry module implementation.
    function trustedIssuersRegistryImplementation() public view returns (address) {
        return _trustedIssuersRegistryImplementation;
    }

    /// @notice Retrieves the current implementation address for the identity factory module.
    /// @return address The current address of the identity factory module implementation.
    function identityFactoryImplementation() public view returns (address) {
        return _identityFactoryImplementation;
    }

    /// @notice Retrieves the current implementation address for the investor identity module.
    /// @return address The current address of the investor identity module implementation.
    function identityImplementation() public view returns (address) {
        return _identityImplementation;
    }

    /// @notice Retrieves the current implementation address for the token identity module.
    /// @return address The current address of the token identity module implementation.
    function tokenIdentityImplementation() public view returns (address) {
        return _tokenIdentityImplementation;
    }

    // --- Proxy Getter Functions ---

    /// @notice Retrieves the current address for the compliance module proxy.
    /// @return address The current address of the compliance module proxy.
    function complianceProxy() public view returns (address) {
        return _complianceProxy;
    }

    /// @notice Retrieves the current address for the identity registry module proxy.
    /// @return address The current address of the identity registry module proxy.
    function identityRegistryProxy() public view returns (address) {
        return _identityRegistryProxy;
    }

    /// @notice Retrieves the current address for the identity registry storage module proxy.
    /// @return address The current address of the identity registry storage module proxy.
    function identityRegistryStorageProxy() public view returns (address) {
        return _identityRegistryStorageProxy;
    }

    /// @notice Retrieves the current address for the trusted issuers registry module proxy.
    /// @return address The current address of the trusted issuers registry module proxy.
    function trustedIssuersRegistryProxy() public view returns (address) {
        return _trustedIssuersRegistryProxy;
    }

    /// @notice Retrieves the current address for the identity factory module proxy.
    /// @return address The current address of the identity factory module proxy.
    function identityFactoryProxy() public view returns (address) {
        return _identityFactoryProxy;
    }

    // --- Internal Functions ---

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
