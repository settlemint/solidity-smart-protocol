// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { AccessControlEnumerableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// OnchainID imports
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
// Interface imports
import { IERC3643IdentityRegistryStorage } from "./../../interface/ERC-3643/IERC3643IdentityRegistryStorage.sol";

// --- Errors ---
error InvalidIdentityWalletAddress();
error InvalidIdentityAddress();
error IdentityAlreadyExists(address userAddress);
error IdentityDoesNotExist(address userAddress);
error InvalidIdentityRegistryAddress();
error IdentityRegistryAlreadyBound(address registryAddress);
error IdentityRegistryNotBound(address registryAddress);
error UnauthorizedCaller();

/// @title SMART Identity Registry Storage
/// @notice Upgradeable storage contract for identity registry data, adhering to ERC-3643 storage interface.
/// @dev Stores mappings between investor wallets, their `IIdentity` contracts, and country codes.
///      Manages which `SMARTIdentityRegistry` contracts are authorized to modify this storage.
///      Uses AccessControl for administration (binding registries) and UUPS for upgradeability.
contract SMARTIdentityRegistryStorageImplementation is
    Initializable,
    ERC2771ContextUpgradeable,
    AccessControlEnumerableUpgradeable,
    IERC3643IdentityRegistryStorage
{
    // --- Roles ---
    /// @notice Role granted to bound `SMARTIdentityRegistry` contracts allowing them to modify storage.
    bytes32 public constant STORAGE_MODIFIER_ROLE = keccak256("STORAGE_MODIFIER_ROLE");

    /// @notice Role granted to the `SMARTIdentityFactory` contract allowing it to manage bound registries.
    bytes32 public constant MANAGE_REGISTRIES_ROLE = keccak256("MANAGE_REGISTRIES_ROLE");

    // --- Storage Variables ---
    /// @notice Struct holding the identity contract address and country code for a wallet.
    struct Identity {
        address identityContract;
        uint16 country;
    }

    /// @notice Mapping from investor wallet address => Identity struct.
    mapping(address => Identity) private _identities;
    /// @notice Array storing all wallet addresses that have a registered identity.
    address[] private _identityWallets;
    /// @notice Mapping from wallet address => index+1 in the `_identityWallets` array (for O(1) removal).
    mapping(address => uint256) private _identityWalletsIndex;

    /// @notice Mapping indicating if an `SMARTIdentityRegistry` address is bound (true) or not (false).
    mapping(address => bool) private _boundIdentityRegistries;
    /// @notice Array storing the addresses of all bound `SMARTIdentityRegistry` contracts.
    address[] private _boundIdentityRegistryAddresses;
    /// @notice Mapping from bound registry address => index+1 in the `_boundIdentityRegistryAddresses` array (for O(1)
    /// removal).
    mapping(address => uint256) private _boundIdentityRegistriesIndex;

    // --- Events ---
    /// @notice Emitted when a new identity record is stored.
    event IdentityStored(address indexed _identityWallet, IIdentity indexed _identity);
    /// @notice Emitted when an identity record is removed.
    event IdentityUnstored(address indexed _identityWallet, IIdentity indexed _identity);
    /// @notice Emitted when the `IIdentity` contract address for a wallet is modified.
    event IdentityModified(IIdentity indexed _oldIdentity, IIdentity indexed _newIdentity);
    /// @notice Emitted when the country code for a wallet is modified.
    event CountryModified(address indexed _identityWallet, uint16 _country);
    /// @notice Emitted when an `SMARTIdentityRegistry` contract is authorized to modify storage.
    event IdentityRegistryBound(address indexed _identityRegistry);
    /// @notice Emitted when an `SMARTIdentityRegistry` contract's authorization is revoked.
    event IdentityRegistryUnbound(address indexed _identityRegistry);

    // --- Constructor --- (Disable direct construction)
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @notice Initializes the identity registry storage contract.
    /// @dev Sets up AccessControl with default admin rules and UUPS upgradeability.
    ///      Grants the initial admin the `DEFAULT_ADMIN_ROLE` and `STORAGE_MODIFIER_ROLE`.
    /// @param initialAdmin The address for the initial admin role.
    function initialize(address system, address initialAdmin) public initializer {
        __ERC165_init_unchained(); // ERC165 is a base of AccessControlEnumerableUpgradeable
        __AccessControlEnumerable_init_unchained();
        // ERC2771Context is initialized by its constructor

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin); // Manually grant DEFAULT_ADMIN_ROLE
        _grantRole(STORAGE_MODIFIER_ROLE, initialAdmin); // Manually grant STORAGE_MODIFIER_ROLE

        _grantRole(MANAGE_REGISTRIES_ROLE, system); // Grant MANAGE_REGISTRIES_ROLE to the system contract
    }

    // --- Storage Modification Functions (STORAGE_MODIFIER_ROLE required) ---

    /// @inheritdoc IERC3643IdentityRegistryStorage
    /// @dev Requires caller to have `STORAGE_MODIFIER_ROLE`.
    function addIdentityToStorage(
        address _userAddress,
        IIdentity _identity,
        uint16 _country
    )
        external
        override
        onlyRole(STORAGE_MODIFIER_ROLE)
    {
        if (_userAddress == address(0)) revert InvalidIdentityWalletAddress();
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();
        // Check existence using internal state directly for efficiency
        if (_identities[_userAddress].identityContract != address(0)) revert IdentityAlreadyExists(_userAddress);

        _identities[_userAddress] = Identity(address(_identity), _country);
        _identityWallets.push(_userAddress);
        _identityWalletsIndex[_userAddress] = _identityWallets.length; // Store index + 1

        emit IdentityStored(_userAddress, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    /// @dev Requires caller to have `STORAGE_MODIFIER_ROLE`.
    function removeIdentityFromStorage(address _userAddress) external override onlyRole(STORAGE_MODIFIER_ROLE) {
        // Check existence using internal state
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);

        // Efficiently remove from _identityWallets array using the swap-and-pop pattern
        uint256 indexToRemove = _identityWalletsIndex[_userAddress] - 1; // Adjust index to 0-based
        address lastWalletAddress = _identityWallets[_identityWallets.length - 1];

        // Only swap if the element to remove is not the last element
        if (_userAddress != lastWalletAddress) {
            _identityWallets[indexToRemove] = lastWalletAddress;
            _identityWalletsIndex[lastWalletAddress] = indexToRemove + 1; // Update index of the moved element (+1 for
                // storage)
        }

        _identityWallets.pop(); // Remove the last element
        delete _identityWalletsIndex[_userAddress]; // Clean up index mapping for the removed address
        delete _identities[_userAddress]; // Clean up identity data

        emit IdentityUnstored(_userAddress, oldIdentity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    /// @dev Requires caller to have `STORAGE_MODIFIER_ROLE`.
    function modifyStoredIdentity(
        address _userAddress,
        IIdentity _identity
    )
        external
        override
        onlyRole(STORAGE_MODIFIER_ROLE)
    {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();

        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);
        _identities[_userAddress].identityContract = address(_identity);

        emit IdentityModified(oldIdentity, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    /// @dev Requires caller to have `STORAGE_MODIFIER_ROLE`.
    function modifyStoredInvestorCountry(
        address _userAddress,
        uint16 _country
    )
        external
        override
        onlyRole(STORAGE_MODIFIER_ROLE)
    {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);

        _identities[_userAddress].country = _country;

        emit CountryModified(_userAddress, _country);
    }

    // --- Registry Binding Functions (DEFAULT_ADMIN_ROLE required) ---

    /// @notice Authorizes an `SMARTIdentityRegistry` contract to modify this storage.
    /// @dev Requires caller to have `DEFAULT_ADMIN_ROLE`. Grants `STORAGE_MODIFIER_ROLE` to the registry.
    /// @param _identityRegistry The address of the `SMARTIdentityRegistry` contract to bind.
    function bindIdentityRegistry(address _identityRegistry) external onlyRole(MANAGE_REGISTRIES_ROLE) {
        if (_identityRegistry == address(0)) revert InvalidIdentityRegistryAddress();
        if (_boundIdentityRegistries[_identityRegistry]) revert IdentityRegistryAlreadyBound(_identityRegistry);

        _boundIdentityRegistries[_identityRegistry] = true;
        _boundIdentityRegistryAddresses.push(_identityRegistry);
        _boundIdentityRegistriesIndex[_identityRegistry] = _boundIdentityRegistryAddresses.length; // Store index + 1

        _grantRole(STORAGE_MODIFIER_ROLE, _identityRegistry);

        emit IdentityRegistryBound(_identityRegistry);
    }

    /// @notice Revokes authorization for an `SMARTIdentityRegistry` contract to modify this storage.
    /// @dev Requires caller to have `DEFAULT_ADMIN_ROLE`. Revokes `STORAGE_MODIFIER_ROLE` from the registry.
    /// @param _identityRegistry The address of the `SMARTIdentityRegistry` contract to unbind.
    function unbindIdentityRegistry(address _identityRegistry) external onlyRole(MANAGE_REGISTRIES_ROLE) {
        if (!_boundIdentityRegistries[_identityRegistry]) revert IdentityRegistryNotBound(_identityRegistry);

        _revokeRole(STORAGE_MODIFIER_ROLE, _identityRegistry);

        // Efficiently remove from _boundIdentityRegistryAddresses array using swap-and-pop
        uint256 indexToRemove = _boundIdentityRegistriesIndex[_identityRegistry] - 1; // Adjust to 0-based
        address lastRegistry = _boundIdentityRegistryAddresses[_boundIdentityRegistryAddresses.length - 1];

        // Only swap if not removing the last element
        if (_identityRegistry != lastRegistry) {
            _boundIdentityRegistryAddresses[indexToRemove] = lastRegistry;
            _boundIdentityRegistriesIndex[lastRegistry] = indexToRemove + 1; // Update index of moved element (+1 for
                // storage)
        }

        _boundIdentityRegistryAddresses.pop(); // Remove the last element
        delete _boundIdentityRegistriesIndex[_identityRegistry]; // Clean up index mapping
        _boundIdentityRegistries[_identityRegistry] = false; // Update bound status

        emit IdentityRegistryUnbound(_identityRegistry);
    }

    // --- View Functions ---

    /// @notice Returns the list of `SMARTIdentityRegistry` contracts currently bound to this storage.
    function linkedIdentityRegistries() external view returns (address[] memory) {
        return _boundIdentityRegistryAddresses;
    }

    /// @notice Retrieves the `IIdentity` contract address associated with a registered investor address.
    function storedIdentity(address _userAddress) external view returns (IIdentity) {
        address identityAddr = _identities[_userAddress].identityContract;
        if (identityAddr == address(0)) revert IdentityDoesNotExist(_userAddress);
        return IIdentity(identityAddr);
    }

    /// @notice Retrieves the numeric country code associated with a registered investor address.
    function storedInvestorCountry(address _userAddress) external view returns (uint16) {
        address identityAddr = _identities[_userAddress].identityContract;
        if (identityAddr == address(0)) revert IdentityDoesNotExist(_userAddress);
        return _identities[_userAddress].country;
    }

    /// @notice Returns the list of all wallet addresses that have a registered identity.
    function getIdentityWallets() external view returns (address[] memory) {
        return _identityWallets;
    }

    // --- Context Overrides (ERC2771) ---

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

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC3643IdentityRegistryStorage).interfaceId || super.supportsInterface(interfaceId);
    }
}
