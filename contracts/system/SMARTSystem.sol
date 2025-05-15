// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { ERC2771Context, Context } from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { ISMARTSystem } from "./ISMARTSystem.sol";
import {
    ComplianceImplementationNotSet,
    IdentityRegistryImplementationNotSet,
    IdentityRegistryStorageImplementationNotSet,
    TrustedIssuersRegistryImplementationNotSet,
    IdentityFactoryImplementationNotSet,
    IdentityImplementationNotSet,
    TokenIdentityImplementationNotSet,
    InvalidImplementationInterface,
    EtherWithdrawalFailed,
    InvalidTokenRegistryAddress,
    TokenRegistryTypeAlreadyRegistered
} from "./SMARTSystemErrors.sol";

// Interface imports
import { ISMARTTokenRegistry } from "./token-registry/ISMARTTokenRegistry.sol";
import { ISMARTCompliance } from "./../interface/ISMARTCompliance.sol";
import { ISMARTIdentityFactory } from "./identity-factory/ISMARTIdentityFactory.sol"; // Reverted to original path
import { IERC3643TrustedIssuersRegistry } from "./../interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { IERC3643IdentityRegistryStorage } from "./../interface/ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { ISMARTIdentityRegistry } from "./../interface/ISMARTIdentityRegistry.sol";

import { SMARTComplianceProxy } from "./compliance/SMARTComplianceProxy.sol";
import { SMARTIdentityRegistryProxy } from "./identity-registry/SMARTIdentityRegistryProxy.sol";
import { SMARTIdentityRegistryStorageProxy } from "./identity-registry-storage/SMARTIdentityRegistryStorageProxy.sol";
import { SMARTTrustedIssuersRegistryProxy } from "./trusted-issuers-registry/SMARTTrustedIssuersRegistryProxy.sol";
import { SMARTIdentityFactoryProxy } from "./identity-factory/SMARTIdentityFactoryProxy.sol";
import { SMARTTokenRegistryProxy } from "./token-registry/SMARTTokenRegistryProxy.sol";
/// @title SMARTSystem Contract
/// @notice Main contract for managing the SMART Protocol system components and their implementations.
/// @dev This contract handles the deployment and upgrades of various modules like Compliance, Identity Registry, etc.
/// It uses ERC2771Context for meta-transaction support and AccessControl for role-based permissions.

contract SMARTSystem is ISMARTSystem, ERC165, ERC2771Context, AccessControl, ReentrancyGuard {
    // Expected interface IDs
    bytes4 private constant _ISMART_COMPLIANCE_ID = type(ISMARTCompliance).interfaceId;
    bytes4 private constant _ISMART_IDENTITY_REGISTRY_ID = type(ISMARTIdentityRegistry).interfaceId;
    bytes4 private constant _IERC3643_IDENTITY_REGISTRY_STORAGE_ID = type(IERC3643IdentityRegistryStorage).interfaceId;
    bytes4 private constant _IERC3643_TRUSTED_ISSUERS_REGISTRY_ID = type(IERC3643TrustedIssuersRegistry).interfaceId;
    bytes4 private constant _ISMART_IDENTITY_FACTORY_ID = type(ISMARTIdentityFactory).interfaceId;

    // --- Events ---

    /// @notice Emitted when the compliance module implementation is updated.
    /// @param newImplementation The address of the new compliance module implementation.
    event ComplianceImplementationUpdated(address indexed sender, address indexed newImplementation);
    /// @notice Emitted when the identity registry module implementation is updated.
    /// @param newImplementation The address of the new identity registry module implementation.
    event IdentityRegistryImplementationUpdated(address indexed sender, address indexed newImplementation);
    /// @notice Emitted when the identity registry storage module implementation is updated.
    /// @param newImplementation The address of the new identity registry storage module implementation.
    event IdentityRegistryStorageImplementationUpdated(address indexed sender, address indexed newImplementation);
    /// @notice Emitted when the trusted issuers registry module implementation is updated.
    /// @param newImplementation The address of the new trusted issuers registry module implementation.
    event TrustedIssuersRegistryImplementationUpdated(address indexed sender, address indexed newImplementation);
    /// @notice Emitted when the identity factory module implementation is updated.
    /// @param newImplementation The address of the new identity factory module implementation.
    event IdentityFactoryImplementationUpdated(address indexed sender, address indexed newImplementation);
    /// @notice Emitted when the investor identity module implementation is updated.
    /// @param newImplementation The address of the new investor identity module implementation.
    event IdentityImplementationUpdated(address indexed sender, address indexed newImplementation);
    /// @notice Emitted when the token identity module implementation is updated.
    /// @param newImplementation The address of the new token identity module implementation.
    event TokenIdentityImplementationUpdated(address indexed sender, address indexed newImplementation);
    /// @notice Emitted when the system has been bootstrapped, creating proxy contracts for all modules.
    /// @param complianceProxy The address of the deployed SMARTComplianceProxy.
    /// @param identityRegistryProxy The address of the deployed SMARTIdentityRegistryProxy.
    /// @param identityRegistryStorageProxy The address of the deployed SMARTIdentityRegistryStorageProxy.
    /// @param trustedIssuersRegistryProxy The address of the deployed SMARTTrustedIssuersRegistryProxy.
    /// @param identityFactoryProxy The address of the deployed SMARTIdentityFactoryProxy.
    event Bootstrapped(
        address indexed sender,
        address complianceProxy,
        address identityRegistryProxy,
        address identityRegistryStorageProxy,
        address trustedIssuersRegistryProxy,
        address identityFactoryProxy
    );

    /// @notice Emitted when a SMARTTokenRegistry is registered.
    /// @param sender The address that registered the token registry.
    /// @param typeName The human-readable type name of the token registry.
    /// @param proxyAddress The address of the deployed token registry proxy.
    /// @param implementationAddress The address of the deployed token registry implementation.
    event TokenRegistryCreated(
        address indexed sender, string typeName, address proxyAddress, address implementationAddress, uint256 timestamp
    );

    /// @notice Emitted when Ether is withdrawn from the contract by an admin.
    /// @param to The address receiving the Ether.
    /// @param amount The amount of Ether withdrawn.
    event EtherWithdrawn(address indexed to, uint256 amount);

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

    // Token Registries by Type
    mapping(bytes32 typeHash => address tokenRegistryImplementationAddress) private tokenRegistryImplementationsByType;
    mapping(bytes32 typeHash => address tokenRegistryProxyAddress) private tokenRegistryProxiesByType;

    // --- Internal Helper for Interface Check ---
    function _checkInterface(address implAddress, bytes4 interfaceId) private view {
        if (implAddress == address(0)) return; // Allow zero address, checked by specific NotSet errors elsewhere
        try IERC165(implAddress).supportsInterface(interfaceId) returns (bool supported) {
            if (!supported) {
                revert InvalidImplementationInterface(implAddress, interfaceId);
            }
        } catch {
            revert InvalidImplementationInterface(implAddress, interfaceId);
        }
    }

    // --- Constructor ---
    constructor(
        address initialAdmin_,
        address complianceImplementation_,
        address identityRegistryImplementation_,
        address identityRegistryStorageImplementation_,
        address trustedIssuersRegistryImplementation_,
        address identityFactoryImplementation_,
        address identityImplementation_, // Expected to be IERC734 compliant
        address tokenIdentityImplementation_, // Expected to be IERC734 compliant
        address forwarder_
    )
        payable
        ERC2771Context(forwarder_)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin_);

        if (complianceImplementation_ == address(0)) revert ComplianceImplementationNotSet();
        _checkInterface(complianceImplementation_, _ISMART_COMPLIANCE_ID);
        _complianceImplementation = complianceImplementation_;

        if (identityRegistryImplementation_ == address(0)) revert IdentityRegistryImplementationNotSet();
        _checkInterface(identityRegistryImplementation_, _ISMART_IDENTITY_REGISTRY_ID);
        _identityRegistryImplementation = identityRegistryImplementation_;

        if (identityRegistryStorageImplementation_ == address(0)) revert IdentityRegistryStorageImplementationNotSet();
        _checkInterface(identityRegistryStorageImplementation_, _IERC3643_IDENTITY_REGISTRY_STORAGE_ID);
        _identityRegistryStorageImplementation = identityRegistryStorageImplementation_;

        if (trustedIssuersRegistryImplementation_ == address(0)) revert TrustedIssuersRegistryImplementationNotSet();
        _checkInterface(trustedIssuersRegistryImplementation_, _IERC3643_TRUSTED_ISSUERS_REGISTRY_ID);
        _trustedIssuersRegistryImplementation = trustedIssuersRegistryImplementation_;

        if (identityFactoryImplementation_ == address(0)) revert IdentityFactoryImplementationNotSet();
        _checkInterface(identityFactoryImplementation_, _ISMART_IDENTITY_FACTORY_ID);
        _identityFactoryImplementation = identityFactoryImplementation_;

        if (identityImplementation_ == address(0)) revert IdentityImplementationNotSet();
        _checkInterface(identityImplementation_, type(IIdentity).interfaceId);
        _identityImplementation = identityImplementation_;

        if (tokenIdentityImplementation_ == address(0)) revert TokenIdentityImplementationNotSet();
        _checkInterface(tokenIdentityImplementation_, type(IIdentity).interfaceId);
        _tokenIdentityImplementation = tokenIdentityImplementation_;
    }

    // --- Bootstrap Function ---
    /// @inheritdoc ISMARTSystem
    function bootstrap() public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        // --- Checks ---
        if (_complianceImplementation == address(0)) revert ComplianceImplementationNotSet();
        if (_identityRegistryImplementation == address(0)) revert IdentityRegistryImplementationNotSet();
        if (_identityRegistryStorageImplementation == address(0)) revert IdentityRegistryStorageImplementationNotSet();
        if (_trustedIssuersRegistryImplementation == address(0)) revert TrustedIssuersRegistryImplementationNotSet();
        if (_identityFactoryImplementation == address(0)) revert IdentityFactoryImplementationNotSet();

        address initialAdmin = _msgSender();

        // --- Interactions (Part 1: Create proxy instances and store in local variables) ---
        // Create all proxy instances first and capture their addresses in local variables.
        // This helps to separate the "interaction" of contract creation from "effects" on state.
        address localComplianceProxy = address(new SMARTComplianceProxy(address(this)));
        address localIdentityRegistryStorageProxy =
            address(new SMARTIdentityRegistryStorageProxy(address(this), initialAdmin));
        address localTrustedIssuersRegistryProxy =
            address(new SMARTTrustedIssuersRegistryProxy(address(this), initialAdmin));
        // Note: SMARTIdentityRegistryProxy's constructor takes the addresses of other newly created proxies.
        // These are passed as local variables, which is fine as they don't rely on this contract's state being
        // prematurely read.
        address localIdentityRegistryProxy = address(
            new SMARTIdentityRegistryProxy(
                address(this), initialAdmin, localIdentityRegistryStorageProxy, localTrustedIssuersRegistryProxy
            )
        );
        address localIdentityFactoryProxy = address(new SMARTIdentityFactoryProxy(address(this), initialAdmin));

        // --- Effects (Update state variables) ---
        // Now, update all state variables in one go using the addresses from local variables.
        _complianceProxy = localComplianceProxy;
        _identityRegistryStorageProxy = localIdentityRegistryStorageProxy;
        _trustedIssuersRegistryProxy = localTrustedIssuersRegistryProxy;
        _identityRegistryProxy = localIdentityRegistryProxy;
        _identityFactoryProxy = localIdentityFactoryProxy;

        // --- Interactions (Part 2: Call methods on newly created proxies) ---
        // All state variables for proxies are now set.
        // Perform any interactions that depend on the new state.
        IERC3643IdentityRegistryStorage(localIdentityRegistryStorageProxy).bindIdentityRegistry(
            localIdentityRegistryProxy // Using local variable, or _identityRegistryProxy which is now set.
        );

        emit Bootstrapped(
            _msgSender(),
            _complianceProxy, // These will now use the updated state values
            _identityRegistryProxy,
            _identityRegistryStorageProxy,
            _trustedIssuersRegistryProxy,
            _identityFactoryProxy
        );
    }

    /// @inheritdoc ISMARTSystem
    function createTokenRegistry(
        string calldata _typeName,
        address _implementation
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        if (address(_implementation) == address(0)) revert InvalidTokenRegistryAddress();
        _checkInterface(_implementation, type(ISMARTTokenRegistry).interfaceId);

        bytes32 registryTypeHash = keccak256(abi.encodePacked(_typeName));

        if (tokenRegistryImplementationsByType[registryTypeHash] != address(0)) {
            revert TokenRegistryTypeAlreadyRegistered(registryTypeHash);
        }

        address _tokenRegistryProxy = address(new SMARTTokenRegistryProxy(address(this), registryTypeHash));

        tokenRegistryImplementationsByType[registryTypeHash] = _implementation;
        tokenRegistryProxiesByType[registryTypeHash] = _tokenRegistryProxy;

        emit TokenRegistryCreated(_msgSender(), _typeName, _tokenRegistryProxy, _implementation, block.timestamp);
    }

    // --- Implementation Setter Functions ---
    /// @notice Sets the compliance implementation address.
    /// @param implementation The address of the new compliance implementation.
    function setComplianceImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (implementation == address(0)) revert ComplianceImplementationNotSet();
        _checkInterface(implementation, _ISMART_COMPLIANCE_ID);
        _complianceImplementation = implementation;
        emit ComplianceImplementationUpdated(_msgSender(), implementation);
    }

    /// @notice Sets the identity registry implementation address.
    /// @param implementation The address of the new identity registry implementation.
    function setIdentityRegistryImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (implementation == address(0)) revert IdentityRegistryImplementationNotSet();
        _checkInterface(implementation, _ISMART_IDENTITY_REGISTRY_ID);
        _identityRegistryImplementation = implementation;
        emit IdentityRegistryImplementationUpdated(_msgSender(), implementation);
    }

    /// @notice Sets the identity registry storage implementation address.
    /// @param implementation The address of the new identity registry storage implementation.
    function setIdentityRegistryStorageImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (implementation == address(0)) revert IdentityRegistryStorageImplementationNotSet();
        _checkInterface(implementation, _IERC3643_IDENTITY_REGISTRY_STORAGE_ID);
        _identityRegistryStorageImplementation = implementation;
        emit IdentityRegistryStorageImplementationUpdated(_msgSender(), implementation);
    }

    /// @notice Sets the trusted issuers registry implementation address.
    /// @param implementation The address of the new trusted issuers registry implementation.
    function setTrustedIssuersRegistryImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (implementation == address(0)) revert TrustedIssuersRegistryImplementationNotSet();
        _checkInterface(implementation, _IERC3643_TRUSTED_ISSUERS_REGISTRY_ID);
        _trustedIssuersRegistryImplementation = implementation;
        emit TrustedIssuersRegistryImplementationUpdated(_msgSender(), implementation);
    }

    /// @notice Sets the identity factory implementation address.
    /// @param implementation The address of the new identity factory implementation.
    function setIdentityFactoryImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (implementation == address(0)) revert IdentityFactoryImplementationNotSet();
        _checkInterface(implementation, _ISMART_IDENTITY_FACTORY_ID);
        _identityFactoryImplementation = implementation;
        emit IdentityFactoryImplementationUpdated(_msgSender(), implementation);
    }

    /// @notice Sets the identity implementation address.
    /// @param implementation The address of the new identity implementation.
    function setIdentityImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (implementation == address(0)) revert IdentityImplementationNotSet();
        _checkInterface(implementation, type(IIdentity).interfaceId);
        _identityImplementation = implementation;
        emit IdentityImplementationUpdated(_msgSender(), implementation);
    }

    /// @notice Sets the token identity implementation address.
    /// @param implementation The address of the new token identity implementation.
    function setTokenIdentityImplementation(address implementation) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (implementation == address(0)) revert TokenIdentityImplementationNotSet();
        _checkInterface(implementation, type(IIdentity).interfaceId);
        _tokenIdentityImplementation = implementation;
        emit TokenIdentityImplementationUpdated(_msgSender(), implementation);
    }

    // --- Implementation Getter Functions ---
    /// @inheritdoc ISMARTSystem
    function complianceImplementation() public view returns (address) {
        return _complianceImplementation;
    }

    /// @inheritdoc ISMARTSystem
    function identityRegistryImplementation() public view returns (address) {
        return _identityRegistryImplementation;
    }

    /// @inheritdoc ISMARTSystem
    function identityRegistryStorageImplementation() public view returns (address) {
        return _identityRegistryStorageImplementation;
    }

    /// @inheritdoc ISMARTSystem
    function trustedIssuersRegistryImplementation() public view returns (address) {
        return _trustedIssuersRegistryImplementation;
    }

    /// @inheritdoc ISMARTSystem
    function identityFactoryImplementation() public view returns (address) {
        return _identityFactoryImplementation;
    }

    /// @inheritdoc ISMARTSystem
    function identityImplementation() public view returns (address) {
        return _identityImplementation;
    }

    /// @inheritdoc ISMARTSystem
    function tokenIdentityImplementation() public view returns (address) {
        return _tokenIdentityImplementation;
    }

    /// @inheritdoc ISMARTSystem
    function tokenRegistryImplementation(bytes32 registryTypeHash) public view returns (address) {
        return tokenRegistryImplementationsByType[registryTypeHash];
    }

    // --- Proxy Getter Functions ---
    /// @inheritdoc ISMARTSystem
    function complianceProxy() public view returns (address) {
        return _complianceProxy;
    }

    /// @inheritdoc ISMARTSystem
    function identityRegistryProxy() public view returns (address) {
        return _identityRegistryProxy;
    }

    /// @inheritdoc ISMARTSystem
    function identityRegistryStorageProxy() public view returns (address) {
        return _identityRegistryStorageProxy;
    }

    /// @inheritdoc ISMARTSystem
    function trustedIssuersRegistryProxy() public view returns (address) {
        return _trustedIssuersRegistryProxy;
    }

    /// @inheritdoc ISMARTSystem
    function identityFactoryProxy() public view returns (address) {
        return _identityFactoryProxy;
    }

    /// @inheritdoc ISMARTSystem
    function tokenRegistryProxy(bytes32 registryTypeHash) public view returns (address) {
        return tokenRegistryProxiesByType[registryTypeHash];
    }

    /// @notice Allows an admin to withdraw any Ether held by this contract.
    /// @dev This function is typically used to recover Ether sent to the contract accidentally
    /// or if the constructor was made payable and received funds. It can only be called by an
    /// address holding the DEFAULT_ADMIN_ROLE.
    function withdrawEther() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            // Send the entire balance to the caller (admin)
            // slither-disable-next-line low-level-calls
            (bool sent,) = payable(_msgSender()).call{ value: balance }("");
            if (!sent) revert EtherWithdrawalFailed();
            emit EtherWithdrawn(_msgSender(), balance);
        }
    }

    // --- Internal Functions ---
    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return super._msgData();
    }

    function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
        return super._contextSuffixLength();
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC165, AccessControl) returns (bool) {
        return interfaceId == type(ISMARTSystem).interfaceId || super.supportsInterface(interfaceId);
    }
}
