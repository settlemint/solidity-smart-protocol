// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// OnchainID imports
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";

// Constants
import { SMARTSystemRoles } from "../SMARTSystemRoles.sol";

// Interface imports
import { IERC3643IdentityRegistryStorage } from "./../../interface/ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { ISMARTIdentityRegistryStorage } from "./../../interface/ISMARTIdentityRegistryStorage.sol";

// --- Custom Errors for Lost Wallet Management ---
// It's good practice to define specific errors if not already available for clarity.
// Reusing existing errors like InvalidIdentityWalletAddress and InvalidIdentityAddress from the top of the file if they
// exist.

/// @title SMART Identity Registry Storage Implementation
/// @author SettleMint Tokenization Services
/// @notice This contract is the core logic for storing and managing identity-related data for the SMART Protocol.
/// It acts as a persistent data layer for `SMARTIdentityRegistry` contracts, which handle the business logic of
/// identity registration and verification. This separation allows the storage logic to be upgraded independently.
/// @dev This contract implements `IERC3643IdentityRegistryStorage`, a standard interface for storing data related to
/// ERC-3643 compliant identity registries. This includes mapping user wallet addresses to their `IIdentity` contracts
/// (which hold identity claims like KYC/AML status) and their country codes (for compliance purposes).
/// It uses `AccessControlUpgradeable` to manage permissions:
///    - `DEFAULT_ADMIN_ROLE`: This role has the highest level of control. It can grant or revoke any other role,
///      including `MANAGE_REGISTRIES_ROLE`. Typically held by a secure multi-signature wallet or a DAO.
///    - `MANAGE_REGISTRIES_ROLE`: This role is responsible for managing which `SMARTIdentityRegistry` contracts
///      are allowed to interact with this storage. It can bind new registry contracts (granting them
///      `STORAGE_MODIFIER_ROLE`) and unbind existing ones. This role is usually assigned to a system controller
///      contract like `SMARTSystem` or an identity factory.
///    - `STORAGE_MODIFIER_ROLE`: This role is granted to `SMARTIdentityRegistry` contracts that have been "bound"
///      to this storage. Contracts with this role are authorized to call functions that add, remove, or update
///      identity data within this storage contract (e.g., `addIdentityToStorage`, `modifyStoredInvestorCountry`).
/// The contract supports meta-transactions through `ERC2771ContextUpgradeable`, allowing users to interact with it
/// via a trusted forwarder, potentially paying gas fees in tokens other than Ether.
/// It is designed to be upgradeable using the UUPS (Universal Upgradeable Proxy Standard) pattern, meaning the
/// upgrade logic resides within this implementation contract itself.
/// The contract also maintains lists of all registered identity wallets and all bound registry contracts, which can
/// be useful for enumeration, auditing, or administrative purposes.
contract SMARTIdentityRegistryStorageImplementation is
    Initializable,
    ERC2771ContextUpgradeable,
    AccessControlUpgradeable,
    ISMARTIdentityRegistryStorage
{
    // --- Storage Variables ---
    /// @notice Defines a structure to hold the core information for a registered identity.
    /// An `Identity` struct links a user's wallet address to their on-chain identity representation and their country.
    /// @param identityContract The Ethereum address of the ERC725/ERC734 compliant `IIdentity` contract. This contract
    /// stores the user's identity claims, keys, and other related information.
    /// @param country A numerical code (uint16) representing the user's country of residence or jurisdiction. This is
    /// often used for compliance checks, such as ensuring users from certain countries are eligible for specific
    /// services or assets.
    struct Identity {
        address identityContract;
        uint16 country;
    }

    /// @notice Mapping from an investor's wallet address to their `Identity` struct.
    /// @dev This is the primary data structure where identity information is stored.
    /// The key (`address wallet`) is the public wallet address of the user (e.g., their MetaMask address).
    /// The value (`Identity identity`) is the struct containing the address of their `IIdentity` contract and their
    /// country code.
    /// Example: `_identities[0xUserWalletAddress] = Identity(0xIdentityContractAddress, 840)` (840 for USA).
    mapping(address wallet => Identity identity) private _identities;

    /// @notice An array storing the wallet addresses of all users who have a registered identity in this contract.
    /// @dev This array allows for iterating over all registered identities, which can be useful for administrative
    /// tasks, data export, or informational queries (e.g., "how many users are registered?").
    /// It is managed in conjunction with `_identityWalletsIndex` to allow for efficient addition and removal (O(1) for
    /// removal using the swap-and-pop technique).
    address[] private _identityWallets;

    /// @notice Mapping from a user's wallet address to its index (plus one) in the `_identityWallets` array.
    /// @dev This mapping is a crucial optimization for removing an address from the `_identityWallets` array.
    /// Instead of iterating through the array to find the address to remove (which would be O(n) complexity),
    /// this mapping provides the index directly (O(1) lookup).
    /// We store `index + 1` because the default value for a mapping entry is 0. If we stored the actual 0-based index,
    /// we wouldn't be able to distinguish between an address at index 0 and an address that is not in the array.
    /// So, a value of `0` here means the address is not in `_identityWallets`. A value of `1` means it's at index `0`,
    /// etc.
    mapping(address wallet => uint256 indexPlusOne) private _identityWalletsIndex;

    /// @notice Mapping that indicates whether a given `SMARTIdentityRegistry` contract address is currently authorized
    /// (bound) to modify the storage in this contract.
    /// @dev If `_boundIdentityRegistries[registryAddress]` is `true`, it means the `registryAddress` has been granted
    /// the `STORAGE_MODIFIER_ROLE` and can call functions like `addIdentityToStorage`. If `false`, it cannot.
    /// This provides a quick way to check the binding status of a registry without querying the access control system
    /// directly, though the access control system is the ultimate source of truth for permissions.
    mapping(address registry => bool isBound) private _boundIdentityRegistries;

    /// @notice An array storing the addresses of all `SMARTIdentityRegistry` contracts that are currently bound to this
    /// storage contract.
    /// @dev "Binding" means that these registry contracts have been granted the `STORAGE_MODIFIER_ROLE` and are
    /// authorized to write data to this storage contract.
    /// This array allows for iterating over all such authorized registries, for example, to display a list of active
    /// identity providers.
    /// Similar to `_identityWallets`, this array is managed alongside `_boundIdentityRegistriesIndex` for efficient
    /// additions and removals.
    address[] private _boundIdentityRegistryAddresses;

    /// @notice Mapping from a bound `SMARTIdentityRegistry` contract address to its index (plus one) in the
    /// `_boundIdentityRegistryAddresses` array.
    /// @dev This works the same way as `_identityWalletsIndex` but for the `_boundIdentityRegistryAddresses` array.
    /// It enables O(1) complexity for removing a registry address from `_boundIdentityRegistryAddresses` using the
    /// swap-and-pop technique.
    /// Storing `index + 1` helps distinguish non-existence (0) from an actual index of 0.
    mapping(address registry => uint256 indexPlusOne) private _boundIdentityRegistriesIndex;

    // --- Storage Variables for Lost Wallet Management ---
    // Tracks if a wallet address has ever been marked as lost globally
    mapping(address userWallet => bool) private _lostWallets;

    // Tracks lost wallets specifically for each identity contract
    // Mapping: Identity Contract Address => Lost Wallet Address => bool (true if this wallet is lost for this identity)
    mapping(address identityContract => mapping(address userWallet => bool)) private _isWalletLostForSpecificIdentity;

    // Stores an array of lost wallets for each identity contract to allow enumeration
    // Mapping: Identity Contract Address => Array of Lost Wallet Addresses
    mapping(address identityContract => address[]) private _lostWalletsArrayForIdentity;

    // --- Errors ---
    /// @notice Error triggered if an attempt is made to register or operate on an identity with a zero address for the
    /// user's wallet.
    /// @dev This error ensures that every identity record in the system is linked to a valid, non-zero wallet address.
    /// A zero address typically indicates an uninitialized or invalid address in Ethereum.
    error InvalidIdentityWalletAddress();
    /// @notice Error triggered if an attempt is made to register or associate an identity contract that has a zero
    /// address.
    /// @dev This error ensures that all registered identities point to a valid, non-zero `IIdentity` contract address.
    /// The `IIdentity` contract holds the claims and keys related to an identity.
    error InvalidIdentityAddress();
    /// @notice Error triggered when attempting to add an identity to storage for a user address that already has an
    /// identity registered.
    /// @param userAddress The wallet address for which an identity record already exists.
    /// @dev This error prevents duplicate identity registrations for the same wallet address, maintaining data
    /// integrity.
    error IdentityAlreadyExists(address userAddress);
    /// @notice Error triggered when attempting to operate on (e.g., modify, remove) an identity for a user address that
    /// is
    /// not registered.
    /// @param userAddress The wallet address for which no identity record was found in the storage.
    /// @dev This error ensures that operations like modification or removal are only performed on existing identity
    /// records.
    error IdentityDoesNotExist(address userAddress);
    /// @notice Error triggered if an attempt is made to bind an identity registry contract that has a zero address.
    /// @dev This error ensures that only valid, non-zero registry contract addresses can be bound to this storage
    /// contract.
    /// Binding allows a registry contract to modify data in this storage.
    error InvalidIdentityRegistryAddress();
    /// @notice Error triggered when attempting to bind an identity registry contract that is already bound to this
    /// storage.
    /// @param registryAddress The address of the identity registry contract that is already bound.
    /// @dev This error prevents a registry contract from being bound multiple times to this storage.
    error IdentityRegistryAlreadyBound(address registryAddress);
    /// @notice Error triggered when attempting to unbind an identity registry contract that is not currently bound to
    /// this
    /// storage.
    /// @param registryAddress The address of the identity registry contract that was not found in the list of bound
    /// registries.
    /// @dev This error ensures that unbinding operations are only performed on currently bound registry contracts.
    error IdentityRegistryNotBound(address registryAddress);

    // --- Constructor --- (Disable direct construction for upgradeable contract)
    /// @notice Constructor for the `SMARTIdentityRegistryStorageImplementation`.
    /// @dev This constructor is part of the UUPS (Universal Upgradeable Proxy Standard) pattern.
    /// In UUPS, the logic contract (this contract) is deployed, and then a proxy contract points to it.
    /// The constructor's main job here is to initialize the `ERC2771ContextUpgradeable` with the
    /// `trustedForwarder` address. This enables meta-transaction support, allowing users to interact with the
    /// contract without directly paying gas fees in Ether, if a trusted forwarder relays their transactions.
    /// `_disableInitializers()` is called to prevent the `initialize` function (which acts like a constructor for
    /// upgradeable contracts) from being called on this logic contract directly. The `initialize` function
    /// should only be called once, typically by the deployer through the proxy contract after deployment.
    /// @param trustedForwarder The address of the trusted forwarder contract for ERC2771 meta-transactions.
    /// If this is `address(0)`, meta-transactions via a forwarder are effectively disabled for this context, and
    /// `_msgSender()` will behave like the standard `msg.sender`.
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @notice Initializes the `SMARTIdentityRegistryStorageImplementation` contract. This function acts as the
    /// constructor for an upgradeable contract and can only be called once.
    /// @dev This function is typically called by the deployer immediately after the proxy contract pointing to this
    /// implementation is deployed. It sets up the initial state:
    /// 1.  `__ERC165_init_unchained()`: Initializes the ERC165 interface detection mechanism, allowing other contracts
    ///     to query what interfaces this contract supports (e.g., `IERC3643IdentityRegistryStorage`).
    /// 2.  `__AccessControlEnumerable_init_unchained()`: Initializes the role-based access control system. It sets up
    ///     the structures needed to grant, revoke, and check roles.
    /// 3.  `_grantRole(DEFAULT_ADMIN_ROLE, initialAdmin)`: Grants the `DEFAULT_ADMIN_ROLE` to the `initialAdmin`
    ///     address. The admin can manage all other roles and aspects of the access control.
    /// 4.  `_grantRole(STORAGE_MODIFIER_ROLE, initialAdmin)`: Grants the `STORAGE_MODIFIER_ROLE` to the `initialAdmin`.
    ///     This is often a temporary measure for bootstrapping; the `initialAdmin` (or the `DEFAULT_ADMIN_ROLE`
    ///     holder) would typically later grant this role to operational contracts like bound identity registries and
    ///     revoke it from themselves if direct modification by the admin is not intended long-term.
    /// 5.  `_grantRole(MANAGE_REGISTRIES_ROLE, system)`: Grants the `MANAGE_REGISTRIES_ROLE` to the `system` address.
    ///     The `system` address (e.g., a `SMARTSystem` contract or an identity factory contract) is then responsible
    ///     for binding and unbinding `SMARTIdentityRegistry` contracts, which in turn modify the storage.
    /// The `initializer` modifier from `Initializable` ensures this function can only be executed once, preventing
    /// re-initialization.
    /// @param system The address of the system-level contract (e.g., `SMARTSystem` or a factory) that will be granted
    /// the `MANAGE_REGISTRIES_ROLE`. This role allows it to control which identity registry contracts can interact with
    /// and modify the data in this storage.
    /// @param initialAdmin The address that will receive the initial `DEFAULT_ADMIN_ROLE`. This address will also
    /// receive the `STORAGE_MODIFIER_ROLE` initially, though this might be delegated later.
    function initialize(address system, address initialAdmin) public initializer {
        __ERC165_init_unchained(); // Base for AccessControl, initializes ERC165 detection.
        __AccessControl_init_unchained(); // Sets up role-based access control.
        // ERC2771Context is initialized by its own constructor when this contract is created.

        _grantRole(SMARTSystemRoles.DEFAULT_ADMIN_ROLE, initialAdmin); // Admin for managing roles.
        _grantRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE, initialAdmin); // Initial modifier, usually transferred to
            // registries.
        _grantRole(SMARTSystemRoles.MANAGE_REGISTRIES_ROLE, system); // System contract can manage which registries are
            // bound.
        _setRoleAdmin(SMARTSystemRoles.STORAGE_MODIFIER_ROLE, SMARTSystemRoles.MANAGE_REGISTRIES_ROLE);
    }

    // --- Storage Modification Functions (STORAGE_MODIFIER_ROLE required) ---

    /// @inheritdoc IERC3643IdentityRegistryStorage
    /// @notice Adds a new identity record to the storage, linking a user's wallet address to their identity contract
    /// and country code.
    /// @dev This function can only be called by an address that holds the `STORAGE_MODIFIER_ROLE`. Typically, this
    /// role is granted to `SMARTIdentityRegistry` contracts that have been "bound" to this storage.
    /// It performs several critical validation checks before proceeding:
    /// -   The `_userAddress` (the user's external wallet) must not be the zero address (`address(0)`).
    /// -   The `_identity` (the address of the `IIdentity` contract for the user) must not be the zero address.
    /// -   An identity for the given `_userAddress` must not already exist in the storage to prevent duplicates.
    /// If all checks pass, the function:
    /// 1.  Stores the new identity information (identity contract address and country code) in the `_identities`
    /// mapping.
    /// 2.  Adds the `_userAddress` to the `_identityWallets` array for enumeration purposes.
    /// 3.  Updates the `_identityWalletsIndex` mapping to record the position of the new address in the array (for
    /// efficient removal later).
    /// 4.  Emits an `IdentityStored` event to notify off-chain listeners about the new registration.
    /// @param _userAddress The user's external wallet address (e.g., their EOA). This is the primary key for the
    /// identity record.
    /// @param _identity The address of the `IIdentity` contract representing the user's on-chain identity. This
    /// contract would hold claims and keys for the user.
    /// @param _country The numerical country code (uint16) representing the user's jurisdiction, used for compliance.
    /// @dev Reverts with:
    ///      - `InvalidIdentityWalletAddress()` if `_userAddress` is `address(0)`.
    ///      - `InvalidIdentityAddress()` if `_identity` is `address(0)`.
    ///      - `IdentityAlreadyExists(_userAddress)` if an identity is already registered for `_userAddress`.
    function addIdentityToStorage(
        address _userAddress,
        IIdentity _identity,
        uint16 _country
    )
        external
        override
        onlyRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE) // Ensures only authorized contracts can modify storage.
    {
        if (_userAddress == address(0)) revert InvalidIdentityWalletAddress();
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();
        // Check if an identity contract is already registered for this user address.
        // Accessing `_identities[_userAddress].identityContract` directly is efficient.
        if (_identities[_userAddress].identityContract != address(0)) revert IdentityAlreadyExists(_userAddress);

        // Store the new identity information.
        _identities[_userAddress] = Identity(address(_identity), _country);
        // Add the user's wallet address to the list of all identity wallets.
        _identityWallets.push(_userAddress);
        // Store the index (plus one, for 1-based indexing) in the `_identityWalletsIndex` map for O(1) removal later.
        _identityWalletsIndex[_userAddress] = _identityWallets.length;

        emit IdentityStored(_userAddress, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    /// @notice Removes an existing identity record from the storage based on the user's wallet address.
    /// @dev This function can only be called by an address holding the `STORAGE_MODIFIER_ROLE`.
    /// It first checks if an identity actually exists for the given `_userAddress`. If not, it reverts.
    /// If the identity exists, it performs the following actions:
    /// 1.  Retrieves the `IIdentity` contract address associated with the user to include in the event.
    /// 2.  Removes the `_userAddress` from the `_identityWallets` array using the "swap-and-pop" technique. This is an
    ///     O(1) operation:
    ///     a.  It finds the index of `_userAddress` using `_identityWalletsIndex`.
    ///     b.  It takes the last wallet address from the `_identityWallets` array.
    ///     c.  If the address to remove is not the last one, it moves the last address into the slot of the address
    /// being removed.
    ///     d.  It updates `_identityWalletsIndex` for the moved address.
    ///     e.  It then shortens the `_identityWallets` array by one (pop).
    /// 3.  Deletes the entry for `_userAddress` from the `_identityWalletsIndex` mapping.
    /// 4.  Deletes the entry for `_userAddress` from the main `_identities` mapping.
    /// 5.  Emits an `IdentityUnstored` event to notify off-chain listeners.
    /// @param _userAddress The user's external wallet address whose identity record is to be removed.
    /// @dev Reverts with `IdentityDoesNotExist(_userAddress)` if no identity record is found for the `_userAddress`.
    function removeIdentityFromStorage(address _userAddress)
        external
        override
        onlyRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE)
    {
        // Ensure an identity exists for this user address before attempting removal.
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);

        // --- Efficiently remove from _identityWallets array (swap-and-pop) ---
        // Get the 0-based index of the element to remove.
        // `_identityWalletsIndex` stores index+1, so subtract 1.
        uint256 indexToRemove = _identityWalletsIndex[_userAddress] - 1;
        // Get the address of the last element in the array.
        address lastWalletAddress = _identityWallets[_identityWallets.length - 1];

        // If the element to remove is not the last element in the array,
        // move the last element to the position of the element to remove.
        if (_userAddress != lastWalletAddress) {
            _identityWallets[indexToRemove] = lastWalletAddress;
            // Update the index mapping for the element that was moved.
            // Store 1-based index (indexToRemove + 1).
            _identityWalletsIndex[lastWalletAddress] = indexToRemove + 1;
        }

        // Remove the last element from the array (either the original last element or the one just moved).
        _identityWallets.pop();
        // Clean up the index mapping for the removed address by deleting its entry.
        delete _identityWalletsIndex[_userAddress];
        // Clean up the main identity data mapping for the removed address by deleting its entry.
        delete _identities[_userAddress];

        emit IdentityUnstored(_userAddress, oldIdentity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    /// @notice Modifies the `IIdentity` contract address associated with an existing identity record.
    /// @dev This function can only be called by an address holding the `STORAGE_MODIFIER_ROLE`.
    /// It performs checks to ensure:
    /// -   An identity record actually exists for the given `_userAddress`.
    /// -   The new `_identity` contract address is not the zero address.
    /// If both checks pass, it updates the `identityContract` field within the `Identity` struct stored for the
    /// `_userAddress` in the `_identities` mapping.
    /// Finally, it emits an `IdentityModified` event, providing both the old and new `IIdentity` contract addresses.
    /// @param _userAddress The user's external wallet address whose associated `IIdentity` contract is to be updated.
    /// @param _identity The new `IIdentity` contract address to associate with the `_userAddress`.
    /// @dev Reverts with:
    ///      - `IdentityDoesNotExist(_userAddress)` if no identity record is found for `_userAddress`.
    ///      - `InvalidIdentityAddress()` if the new `_identity` address is `address(0)`.
    function modifyStoredIdentity(
        address _userAddress,
        IIdentity _identity
    )
        external
        override
        onlyRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE)
    {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();

        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);
        _identities[_userAddress].identityContract = address(_identity);

        emit IdentityModified(oldIdentity, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    /// @notice Modifies the country code associated with an existing identity record.
    /// @dev This function can only be called by an address holding the `STORAGE_MODIFIER_ROLE`.
    /// It first checks if an identity record exists for the given `_userAddress`. If not, it reverts.
    /// If the identity exists, it updates the `country` field within the `Identity` struct stored for the
    /// `_userAddress` in the `_identities` mapping with the new `_country` code.
    /// Finally, it emits a `CountryModified` event, providing the `_userAddress` and the new `_country` code.
    /// @param _userAddress The user's external wallet address whose associated country code is to be updated.
    /// @param _country The new numerical country code (uint16) to associate with the `_userAddress`.
    /// @dev Reverts with `IdentityDoesNotExist(_userAddress)` if no identity record is found for `_userAddress`.
    function modifyStoredInvestorCountry(
        address _userAddress,
        uint16 _country
    )
        external
        override
        onlyRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE)
    {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);

        _identities[_userAddress].country = _country;

        emit CountryModified(_userAddress, _country);
    }

    // --- Registry Binding Functions (MANAGE_REGISTRIES_ROLE required) ---

    /// @notice Authorizes a `SMARTIdentityRegistry` contract to modify data in this storage contract.
    /// This is achieved by granting the `STORAGE_MODIFIER_ROLE` to the specified registry address.
    /// @dev This function can only be called by an address holding the `MANAGE_REGISTRIES_ROLE` (e.g., a `SMARTSystem`
    /// contract or an identity factory).
    /// It performs several checks:
    /// -   The `_identityRegistry` address must not be the zero address.
    /// -   The `_identityRegistry` must not already be bound to this storage.
    /// If the checks pass, the function:
    /// 1.  Sets `_boundIdentityRegistries[_identityRegistry]` to `true`.
    /// 2.  Adds `_identityRegistry` to the `_boundIdentityRegistryAddresses` array.
    /// 3.  Updates `_boundIdentityRegistriesIndex` for the new registry.
    /// 4.  Grants the `STORAGE_MODIFIER_ROLE` to `_identityRegistry` using the access control mechanism.
    /// 5.  Emits an `IdentityRegistryBound` event.
    /// @param _identityRegistry The address of the `SMARTIdentityRegistry` contract to bind. This registry will then
    /// be able to call functions like `addIdentityToStorage`.
    /// @dev Reverts with:
    ///      - `InvalidIdentityRegistryAddress()` if `_identityRegistry` is `address(0)`.
    ///      - `IdentityRegistryAlreadyBound(_identityRegistry)` if the registry is already bound.
    function bindIdentityRegistry(address _identityRegistry)
        external
        onlyRole(SMARTSystemRoles.MANAGE_REGISTRIES_ROLE)
    {
        if (_identityRegistry == address(0)) revert InvalidIdentityRegistryAddress();
        if (_boundIdentityRegistries[_identityRegistry]) revert IdentityRegistryAlreadyBound(_identityRegistry);

        _boundIdentityRegistries[_identityRegistry] = true;
        _boundIdentityRegistryAddresses.push(_identityRegistry);
        _boundIdentityRegistriesIndex[_identityRegistry] = _boundIdentityRegistryAddresses.length; // Store 1-based
            // index.

        _grantRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE, _identityRegistry); // Grant role to the registry contract.

        emit IdentityRegistryBound(_identityRegistry);
    }

    /// @notice Revokes the authorization for a `SMARTIdentityRegistry` contract to modify data in this storage.
    /// This is achieved by revoking the `STORAGE_MODIFIER_ROLE` from the specified registry address.
    /// @dev This function can only be called by an address holding the `MANAGE_REGISTRIES_ROLE`.
    /// It first checks if the `_identityRegistry` is currently bound. If not, it reverts.
    /// If the registry is bound, the function:
    /// 1.  Revokes the `STORAGE_MODIFIER_ROLE` from `_identityRegistry`.
    /// 2.  Removes `_identityRegistry` from the `_boundIdentityRegistryAddresses` array using the "swap-and-pop"
    /// technique (O(1) complexity).
    /// 3.  Updates `_boundIdentityRegistriesIndex` accordingly.
    /// 4.  Sets `_boundIdentityRegistries[_identityRegistry]` to `false`.
    /// 5.  Emits an `IdentityRegistryUnbound` event.
    /// @param _identityRegistry The address of the `SMARTIdentityRegistry` contract to unbind. This registry will no
    /// longer be able to modify storage data.
    /// @dev Reverts with `IdentityRegistryNotBound(_identityRegistry)` if the registry is not currently bound.
    function unbindIdentityRegistry(address _identityRegistry)
        external
        onlyRole(SMARTSystemRoles.MANAGE_REGISTRIES_ROLE)
    {
        if (!_boundIdentityRegistries[_identityRegistry]) revert IdentityRegistryNotBound(_identityRegistry);

        _revokeRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE, _identityRegistry); // Revoke role from the registry
            // contract.

        // --- Efficiently remove from _boundIdentityRegistryAddresses array (swap-and-pop) ---
        uint256 indexToRemove = _boundIdentityRegistriesIndex[_identityRegistry] - 1; // Adjust to 0-based index.
        address lastRegistry = _boundIdentityRegistryAddresses[_boundIdentityRegistryAddresses.length - 1];

        if (_identityRegistry != lastRegistry) {
            _boundIdentityRegistryAddresses[indexToRemove] = lastRegistry;
            // Update 1-based index for the element that was moved.
            _boundIdentityRegistriesIndex[lastRegistry] = indexToRemove + 1;
        }

        _boundIdentityRegistryAddresses.pop();
        delete _boundIdentityRegistriesIndex[_identityRegistry];
        _boundIdentityRegistries[_identityRegistry] = false; // Mark as unbound.

        emit IdentityRegistryUnbound(_identityRegistry);
    }

    // --- View Functions ---

    /// @notice Returns an array of addresses of all `SMARTIdentityRegistry` contracts currently bound to this storage.
    /// @dev "Bound" means these registry contracts have been granted the `STORAGE_MODIFIER_ROLE` and are authorized
    /// to write data to this storage contract. This function provides a way to discover which registry contracts are
    /// active and can modify identity data.
    /// @return An array of `address` types, where each address is that of a bound identity registry contract.
    /// The array will be empty if no registries are currently bound.
    function linkedIdentityRegistries() external view returns (address[] memory) {
        return _boundIdentityRegistryAddresses;
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    /// @notice Retrieves the `IIdentity` contract address associated with a registered user's wallet address.
    /// @dev This function performs a direct lookup in the `_identities` mapping.
    /// It first checks if an `identityContract` is stored for the `_userAddress` (i.e., it's not `address(0)`).
    /// If no identity contract is found (meaning the `_userAddress` is not registered or has been removed),
    /// the function reverts with the `IdentityDoesNotExist` error.
    /// @param _userAddress The user's external wallet address for which to retrieve the associated `IIdentity`
    /// contract.
    /// @return The `IIdentity` contract address linked to the `_userAddress`. This is returned as an `IIdentity` type
    /// for type safety, but it's fundamentally an address.
    /// @dev Reverts with `IdentityDoesNotExist(_userAddress)` if no identity record is found for the `_userAddress`.
    function storedIdentity(address _userAddress) external view override returns (IIdentity) {
        address identityAddr = _identities[_userAddress].identityContract;
        if (identityAddr == address(0)) revert IdentityDoesNotExist(_userAddress);
        return IIdentity(identityAddr);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    /// @notice Retrieves the numerical country code associated with a registered user's wallet address.
    /// @dev This function performs a direct lookup in the `_identities` mapping for the given `_userAddress`.
    /// It first checks if an `identityContract` is associated with the `_userAddress`. This is a crucial check because
    /// a country code should only be considered valid if there's an active identity registration.
    /// If no `identityContract` is found (i.e., the address is `address(0)`), it implies the user is not registered or
    /// their identity has been removed, so the function reverts with `IdentityDoesNotExist`.
    /// If an identity contract exists, the function returns the `country` field from the `Identity` struct.
    /// @param _userAddress The user's external wallet address for which to retrieve the associated country code.
    /// @return The `uint16` country code associated with the `_userAddress`.
    /// @dev Reverts with `IdentityDoesNotExist(_userAddress)` if no identity record (specifically, no identity
    /// contract) is found for the `_userAddress`.
    function storedInvestorCountry(address _userAddress) external view override returns (uint16) {
        address identityAddr = _identities[_userAddress].identityContract;
        // This check ensures that we only return a country code if an identity contract is also present.
        // A country code without an associated identity contract is considered invalid or non-existent.
        if (identityAddr == address(0)) revert IdentityDoesNotExist(_userAddress);
        return _identities[_userAddress].country;
    }

    /// @notice Returns an array of all wallet addresses that have a registered identity in this storage contract.
    /// @dev This function provides a way to enumerate all users who currently have an active identity record stored.
    /// It's useful for administrative purposes, data analysis, or for front-ends that need to display a list of all
    /// registered users.
    /// @return An array of `address` types, where each address is a wallet address that has a stored identity.
    /// The array will be empty if no identities are currently registered.
    function getIdentityWallets() external view returns (address[] memory) {
        return _identityWallets;
    }

    // --- Lost Wallet Management Functions ---

    /// @inheritdoc ISMARTIdentityRegistryStorage
    function markWalletAsLost(
        address identityContract,
        address userWallet
    )
        external
        override
        onlyRole(SMARTSystemRoles.STORAGE_MODIFIER_ROLE)
    {
        if (userWallet == address(0)) revert InvalidIdentityWalletAddress();
        if (identityContract == address(0)) revert InvalidIdentityAddress();

        _lostWallets[userWallet] = true;

        // Add to specific identity lost list if not already there
        // This ensures idempotency for marking a wallet as lost for a specific identity.
        if (!_isWalletLostForSpecificIdentity[identityContract][userWallet]) {
            _isWalletLostForSpecificIdentity[identityContract][userWallet] = true;
            _lostWalletsArrayForIdentity[identityContract].push(userWallet);
        }
        // The event is emitted regardless, as the intent is to mark/confirm it as lost.
        emit IdentityWalletMarkedAsLost(identityContract, userWallet, _msgSender());
    }

    /// @inheritdoc ISMARTIdentityRegistryStorage
    function isWalletMarkedAsLost(address userWallet) external view override returns (bool) {
        return _lostWallets[userWallet];
    }

    /// @inheritdoc ISMARTIdentityRegistryStorage
    function isWalletMarkedAsLostForIdentity(
        address identityContract,
        address userWallet
    )
        external
        view
        override
        returns (bool)
    {
        return _isWalletLostForSpecificIdentity[identityContract][userWallet];
    }

    /// @inheritdoc ISMARTIdentityRegistryStorage
    function getLostWalletsForIdentityFromStorage(address identityContract)
        external
        view
        override
        returns (address[] memory)
    {
        // It's good practice to check if identityContract is non-zero, though mapping access won't revert.
        // However, returning an empty array for address(0) might be clearer than current behavior if not explicitly
        // handled.
        // For now, directly returning based on the current minimal approach.
        return _lostWalletsArrayForIdentity[identityContract];
    }

    // --- Context Overrides (ERC2771 for meta-transactions) ---

    /// @notice Provides the actual sender of a transaction, supporting meta-transactions via ERC2771.
    /// @dev This function overrides the standard `_msgSender()` from `ContextUpgradeable` and also the one from
    /// `ERC2771ContextUpgradeable` (though the latter is what's effectively being used).
    /// When a transaction is relayed by a trusted forwarder (as configured in the `ERC2771ContextUpgradeable`
    /// constructor), this function returns the address of the original user who signed the transaction, not the
    /// address of the forwarder.
    /// If the transaction is not relayed (i.e., it's a direct call), this function returns `msg.sender` as usual.
    /// This is crucial for access control (`onlyRole` modifiers) and event emissions, ensuring that actions are
    /// attributed to the correct originating user, even when gas is paid by a third party.
    /// @return The address of the original transaction sender (user) if relayed via a trusted forwarder,
    /// or `msg.sender` if called directly.
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /// @notice Provides the actual transaction data, supporting meta-transactions via ERC2771.
    /// @dev Similar to `_msgSender()`, this function overrides the standard `_msgData()` from `ContextUpgradeable`
    /// and `ERC2771ContextUpgradeable`.
    /// When a transaction is relayed by a trusted forwarder, this function returns the original `msg.data` (calldata)
    /// that was sent by the user to the forwarder. This `msg.data` typically contains the encoded function call
    /// intended for this contract.
    /// If the transaction is not relayed, this function returns the current `msg.data` as usual.
    /// This ensures that the contract logic operates on the user's intended call, even if it's wrapped by a forwarder.
    /// @return The original transaction data (calldata) if relayed via a trusted forwarder,
    /// or the current `msg.data` if called directly.
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    /// @notice Returns the length of the suffix appended to transaction data by an ERC2771 trusted forwarder.
    /// @dev This function is part of the ERC2771 standard and is used internally by `ERC2771ContextUpgradeable`.
    /// When a trusted forwarder relays a transaction, it typically appends the original sender's address to the end of
    /// the `msg.data`. This function tells the `ERC2771ContextUpgradeable` logic how many bytes at the end of
    /// `msg.data` constitute this appended sender address.
    /// For Ethereum addresses, this length is 20 bytes.
    /// This allows `_msgSender()` to extract the original sender if the call is coming from a trusted forwarder.
    /// @return The length of the context suffix in bytes (e.g., 20 for an Ethereum address).
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
    /// @notice Indicates whether this contract supports a given interface ID, as per the ERC165 standard.
    /// @dev This function allows other contracts or off-chain tools to query if this contract implements specific
    /// interfaces.
    /// It checks if the `interfaceId` matches:
    /// 1.  `type(IERC3643IdentityRegistryStorage).interfaceId`: This confirms that the contract adheres to the
    ///     standard interface for ERC-3643 compliant identity registry storage.
    /// 2.  Any interfaces supported by its parent contracts (e.g., `AccessControlUpgradeable`,
    ///     `ERC165Upgradeable` itself) by calling `super.supportsInterface(interfaceId)`.
    /// This is crucial for interoperability within the ecosystem, allowing, for example, a `SMARTIdentityRegistry`
    /// to verify that it's interacting with a compatible storage contract.
    /// @param interfaceId The EIP-165 interface identifier (a `bytes4` value) to check for support.
    /// @return `true` if the contract supports the specified `interfaceId`, `false` otherwise.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, IERC165) // Specifies which parent's supportsInterface is being
            // primarily
            // extended.
        returns (bool)
    {
        return interfaceId == type(IERC3643IdentityRegistryStorage).interfaceId || super.supportsInterface(interfaceId);
    }
}
