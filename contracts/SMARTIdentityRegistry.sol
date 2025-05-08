// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

// OnchainID imports
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { IClaimIssuer } from "@onchainid/contracts/interface/IClaimIssuer.sol";

// Interface imports
import { ISMARTIdentityRegistry } from "./interface/ISMARTIdentityRegistry.sol";
import { ISMART } from "./interface/ISMART.sol";

import { IERC3643IdentityRegistryStorage } from "./interface/ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { IERC3643TrustedIssuersRegistry } from "./interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol";

// --- Errors ---
error InvalidStorageAddress();
error InvalidRegistryAddress();
error IdentityNotRegistered(address userAddress);
error InvalidIdentityAddress();
error ArrayLengthMismatch();
error InvalidUserAddress();
error IdentityAlreadyRegistered(address userAddress);

/// @title SMART Identity Registry
/// @notice Upgradeable implementation of the Identity Registry for managing investor identities, compliant with
/// ERC-3643.
/// @dev Uses a separate storage contract (`IERC3643IdentityRegistryStorage`) for identity data
///      and a `IERC3643TrustedIssuersRegistry` for verification logic.
///      Managed by AccessControl and upgradeable via UUPS.
contract SMARTIdentityRegistry is
    Initializable,
    ISMARTIdentityRegistry,
    ERC2771ContextUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    UUPSUpgradeable
{
    // --- Roles ---
    /// @notice Role required to register, update, and delete identities.
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    // --- Storage References ---
    /// @notice Address of the external storage contract holding identity data.
    IERC3643IdentityRegistryStorage private _identityStorage;
    /// @notice Address of the external registry holding trusted claim issuers.
    IERC3643TrustedIssuersRegistry private _trustedIssuersRegistry;

    // --- Events ---
    event IdentityStorageSet(address indexed _identityStorage);
    event TrustedIssuersRegistrySet(address indexed _trustedIssuersRegistry);
    event IdentityRegistered(address indexed _investorAddress, IIdentity indexed _identity);
    event IdentityRemoved(address indexed _investorAddress, IIdentity indexed _identity);
    event IdentityUpdated(IIdentity indexed _oldIdentity, IIdentity indexed _newIdentity);
    event CountryUpdated(address indexed _investorAddress, uint16 indexed _country);

    // --- Constructor ---
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @notice Initializes the identity registry.
    /// @dev Sets up AccessControl, UUPS, and links the storage and trusted issuers registry contracts.
    ///      Grants the initial admin the `DEFAULT_ADMIN_ROLE` and `REGISTRAR_ROLE`.
    /// @param initialAdmin The address for initial admin and registrar roles.
    /// @param identityStorage_ The address of the `IERC3643IdentityRegistryStorage` contract.
    /// @param trustedIssuersRegistry_ The address of the `IERC3643TrustedIssuersRegistry` contract.
    function initialize(
        address initialAdmin,
        address identityStorage_,
        address trustedIssuersRegistry_
    )
        public
        initializer
    {
        __AccessControl_init();
        __AccessControlDefaultAdminRules_init(3 days, initialAdmin);
        __UUPSUpgradeable_init();

        if (identityStorage_ == address(0)) revert InvalidStorageAddress();
        if (trustedIssuersRegistry_ == address(0)) revert InvalidRegistryAddress();

        _grantRole(REGISTRAR_ROLE, initialAdmin);

        _identityStorage = IERC3643IdentityRegistryStorage(identityStorage_);
        emit IdentityStorageSet(address(_identityStorage));
        _trustedIssuersRegistry = IERC3643TrustedIssuersRegistry(trustedIssuersRegistry_);
        emit TrustedIssuersRegistrySet(address(_trustedIssuersRegistry));
    }

    // --- State-Changing Functions ---
    /// @inheritdoc ISMARTIdentityRegistry
    /// @dev Requires `DEFAULT_ADMIN_ROLE`.
    function setIdentityRegistryStorage(address identityStorage_) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (identityStorage_ == address(0)) revert InvalidStorageAddress();
        _identityStorage = IERC3643IdentityRegistryStorage(identityStorage_);
        emit IdentityStorageSet(address(_identityStorage));
    }

    /// @inheritdoc ISMARTIdentityRegistry
    /// @dev Requires `DEFAULT_ADMIN_ROLE`.
    function setTrustedIssuersRegistry(address trustedIssuersRegistry_)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (trustedIssuersRegistry_ == address(0)) revert InvalidRegistryAddress();
        _trustedIssuersRegistry = IERC3643TrustedIssuersRegistry(trustedIssuersRegistry_);
        emit TrustedIssuersRegistrySet(address(_trustedIssuersRegistry));
    }

    /// @inheritdoc ISMARTIdentityRegistry
    /// @dev Requires `REGISTRAR_ROLE`.
    function registerIdentity(
        address _userAddress,
        IIdentity _identity,
        uint16 _country
    )
        external
        override
        onlyRole(REGISTRAR_ROLE)
    {
        _registerIdentity(_userAddress, _identity, _country);
    }

    /// @inheritdoc ISMARTIdentityRegistry
    /// @dev Requires `REGISTRAR_ROLE`.
    function deleteIdentity(address _userAddress) external override onlyRole(REGISTRAR_ROLE) {
        if (!this.contains(_userAddress)) revert IdentityNotRegistered(_userAddress);

        IIdentity identityToDelete = IIdentity(_identityStorage.storedIdentity(_userAddress));
        _identityStorage.removeIdentityFromStorage(_userAddress);

        emit IdentityRemoved(_userAddress, identityToDelete);
    }

    /// @inheritdoc ISMARTIdentityRegistry
    /// @dev Requires `REGISTRAR_ROLE`.
    function updateCountry(address _userAddress, uint16 _country) external override onlyRole(REGISTRAR_ROLE) {
        if (!this.contains(_userAddress)) revert IdentityNotRegistered(_userAddress);

        _identityStorage.modifyStoredInvestorCountry(_userAddress, _country);
        emit CountryUpdated(_userAddress, _country);
    }

    /// @inheritdoc ISMARTIdentityRegistry
    /// @dev Requires `REGISTRAR_ROLE`.
    function updateIdentity(address _userAddress, IIdentity _identity) external override onlyRole(REGISTRAR_ROLE) {
        if (!this.contains(_userAddress)) revert IdentityNotRegistered(_userAddress);
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();

        IIdentity oldInvestorIdentity = IIdentity(_identityStorage.storedIdentity(_userAddress));
        _identityStorage.modifyStoredIdentity(_userAddress, _identity);

        emit IdentityUpdated(oldInvestorIdentity, _identity);
    }

    /// @inheritdoc ISMARTIdentityRegistry
    /// @dev Requires `REGISTRAR_ROLE`.
    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    )
        external
        override
        onlyRole(REGISTRAR_ROLE)
    {
        if (!(_userAddresses.length == _identities.length && _identities.length == _countries.length)) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < _userAddresses.length; i++) {
            _registerIdentity(_userAddresses[i], _identities[i], _countries[i]);
        }
    }

    // --- View Functions ---
    /// @inheritdoc ISMARTIdentityRegistry
    function contains(address _userAddress) external view override returns (bool) {
        try _identityStorage.storedIdentity(_userAddress) returns (IIdentity) {
            return true;
        } catch {
            return false;
        }
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function isVerified(
        address _userAddress,
        uint256[] memory requiredClaimTopics
    )
        external
        view
        override
        returns (bool)
    {
        if (!this.contains(_userAddress)) return false;
        if (requiredClaimTopics.length == 0) return true;

        IIdentity identityToVerify = IIdentity(_identityStorage.storedIdentity(_userAddress));

        for (uint256 i = 0; i < requiredClaimTopics.length; i++) {
            uint256 currentTopic = requiredClaimTopics[i];
            if (currentTopic == 0) continue;

            bool topicVerified = false;

            IClaimIssuer[] memory relevantIssuers = _trustedIssuersRegistry.getTrustedIssuersForClaimTopic(currentTopic);

            for (uint256 j = 0; j < relevantIssuers.length; j++) {
                IClaimIssuer relevantIssuer = relevantIssuers[j];
                bytes32 claimId = keccak256(abi.encode(address(relevantIssuer), currentTopic));

                try identityToVerify.getClaim(claimId) returns (
                    uint256 topic, uint256, address issuer, bytes memory signature, bytes memory data, string memory
                ) {
                    if (issuer == address(relevantIssuer) && topic == currentTopic) {
                        try relevantIssuer.isClaimValid(identityToVerify, topic, signature, data) returns (bool isValid)
                        {
                            if (isValid) {
                                topicVerified = true;
                                break;
                            }
                        } catch {
                            continue;
                        }
                    }
                } catch {
                    continue;
                }
            }

            if (!topicVerified) {
                return false;
            }
        }

        return true;
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function identity(address _userAddress) public view override returns (IIdentity) {
        return IIdentity(_identityStorage.storedIdentity(_userAddress));
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function investorCountry(address _userAddress) external view override returns (uint16) {
        if (!this.contains(_userAddress)) revert IdentityNotRegistered(_userAddress);
        return _identityStorage.storedInvestorCountry(_userAddress);
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function identityStorage() external view override returns (IERC3643IdentityRegistryStorage) {
        return _identityStorage;
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function issuersRegistry() external view override returns (IERC3643TrustedIssuersRegistry) {
        return _trustedIssuersRegistry;
    }

    // --- Internal Functions ---
    /// @dev Internal helper to register an identity, performs checks before calling storage.
    function _registerIdentity(address _userAddress, IIdentity _identity, uint16 _country) internal {
        if (_userAddress == address(0)) revert InvalidUserAddress();
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();
        if (this.contains(_userAddress)) revert IdentityAlreadyRegistered(_userAddress);

        _identityStorage.addIdentityToStorage(_userAddress, _identity, _country);
        emit IdentityRegistered(_userAddress, _identity);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    // --- Upgradeability ---
    /// @dev Authorizes an upgrade to a new implementation.
    ///      Requires the caller to have the `DEFAULT_ADMIN_ROLE`.
    function _authorizeUpgrade(address newImplementation)
        internal
        override(UUPSUpgradeable)
        onlyRole(DEFAULT_ADMIN_ROLE)
    { }
}
