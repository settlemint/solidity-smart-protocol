// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

// Interface imports
import { IERC3643IdentityRegistryStorage } from "../ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { IIdentity } from "../onchainid/interface/IIdentity.sol";

// --- Errors ---
error InvalidIdentityWalletAddress();
error InvalidIdentityAddress();
error IdentityAlreadyExists(address userAddress);
error IdentityDoesNotExist(address userAddress);
error InvalidIdentityRegistryAddress();
error IdentityRegistryAlreadyBound(address registryAddress);
error IdentityRegistryNotBound(address registryAddress);
error UnauthorizedCaller();

/// @title SMARTIdentityRegistryStorage
/// @notice Storage contract for identity registry data.
contract SMARTIdentityRegistryStorage is
    Initializable,
    IERC3643IdentityRegistryStorage,
    ERC2771ContextUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    UUPSUpgradeable
{
    // --- Roles ---
    bytes32 public constant STORAGE_MODIFIER_ROLE = keccak256("STORAGE_MODIFIER_ROLE");

    // --- Storage Variables ---
    struct Identity {
        address identityContract;
        uint16 country;
    }

    // Maps user wallet addresses to their identity information
    mapping(address => Identity) private _identities;
    // Array of all wallet addresses that have an identity
    address[] private _identityWallets;
    // Maps each wallet address to its index in the _identityWallets array for O(1) removal
    mapping(address => uint256) private _identityWalletsIndex;

    // Mapping to track if an Identity Registry address is bound
    mapping(address => bool) private _boundIdentityRegistries;
    // Array to store the addresses of bound Identity Registries
    address[] private _boundIdentityRegistryAddresses;
    // Mapping to store the index of each bound registry in the _boundIdentityRegistryAddresses array for O(1) removal
    mapping(address => uint256) private _boundIdentityRegistriesIndex;

    // --- Events ---
    event IdentityStored(address indexed _identityWallet, IIdentity indexed _identity);
    event IdentityUnstored(address indexed _identityWallet, IIdentity indexed _identity);
    event IdentityModified(IIdentity indexed _oldIdentity, IIdentity indexed _newIdentity);
    event CountryModified(address indexed _identityWallet, uint16 _country);
    event IdentityRegistryBound(address indexed _identityRegistry);
    event IdentityRegistryUnbound(address indexed _identityRegistry);

    // --- Constructor ---
    constructor() ERC2771ContextUpgradeable(address(0)) {
        _disableInitializers();
    }

    // --- Initializer ---
    function initialize(address initialAdmin) public initializer {
        __AccessControl_init();
        __AccessControlDefaultAdminRules_init(3 days, initialAdmin);
        __UUPSUpgradeable_init();

        _grantRole(STORAGE_MODIFIER_ROLE, initialAdmin);
    }

    // --- State-Changing Functions ---
    function addIdentityToStorage(
        address _userAddress,
        IIdentity _identity,
        uint16 _country
    )
        external
        onlyRole(STORAGE_MODIFIER_ROLE)
    {
        if (_userAddress == address(0)) revert InvalidIdentityWalletAddress();
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();
        if (_identities[_userAddress].identityContract != address(0)) revert IdentityAlreadyExists(_userAddress);

        _identities[_userAddress] = Identity(address(_identity), _country);
        _identityWallets.push(_userAddress);
        // Store the index + 1 of the newly added wallet address for O(1) removal checks
        _identityWalletsIndex[_userAddress] = _identityWallets.length;

        emit IdentityStored(_userAddress, _identity);
    }

    function removeIdentityFromStorage(address _userAddress) external onlyRole(STORAGE_MODIFIER_ROLE) {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);

        // Efficiently remove from _identityWallets array using the mapping index
        uint256 indexToRemove = _identityWalletsIndex[_userAddress] - 1; // Adjust index back to 0-based
        address lastWalletAddress = _identityWallets[_identityWallets.length - 1];

        if (_userAddress != lastWalletAddress) {
            // Move the last wallet address to the position of the one being removed
            _identityWallets[indexToRemove] = lastWalletAddress;
            // Update the index mapping for the moved wallet address (index + 1 for storage)
            _identityWalletsIndex[lastWalletAddress] = indexToRemove + 1;
        }

        // Remove the last element
        _identityWallets.pop();

        // Clean up identity data and index mapping
        delete _identities[_userAddress];
        delete _identityWalletsIndex[_userAddress]; // Set index back to 0

        emit IdentityUnstored(_userAddress, oldIdentity);
    }

    function modifyStoredIdentity(address _userAddress, IIdentity _identity) external onlyRole(STORAGE_MODIFIER_ROLE) {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();

        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);
        _identities[_userAddress].identityContract = address(_identity);

        emit IdentityModified(oldIdentity, _identity);
    }

    function modifyStoredInvestorCountry(
        address _userAddress,
        uint16 _country
    )
        external
        onlyRole(STORAGE_MODIFIER_ROLE)
    {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);

        _identities[_userAddress].country = _country;

        emit CountryModified(_userAddress, _country);
    }

    function bindIdentityRegistry(address _identityRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_identityRegistry == address(0)) revert InvalidIdentityRegistryAddress();
        if (_boundIdentityRegistries[_identityRegistry]) revert IdentityRegistryAlreadyBound(_identityRegistry);

        _boundIdentityRegistries[_identityRegistry] = true;
        _boundIdentityRegistryAddresses.push(_identityRegistry);
        // Store index + 1 for O(1) removal checks
        _boundIdentityRegistriesIndex[_identityRegistry] = _boundIdentityRegistryAddresses.length;

        _grantRole(STORAGE_MODIFIER_ROLE, _identityRegistry);

        emit IdentityRegistryBound(_identityRegistry);
    }

    function unbindIdentityRegistry(address _identityRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_boundIdentityRegistries[_identityRegistry]) revert IdentityRegistryNotBound(_identityRegistry);

        _revokeRole(STORAGE_MODIFIER_ROLE, _identityRegistry);

        // Efficiently remove from _boundIdentityRegistryAddresses array
        uint256 indexToRemove = _boundIdentityRegistriesIndex[_identityRegistry] - 1; // Adjust index back to 0-based
        address lastRegistry = _boundIdentityRegistryAddresses[_boundIdentityRegistryAddresses.length - 1];

        if (_identityRegistry != lastRegistry) {
            _boundIdentityRegistryAddresses[indexToRemove] = lastRegistry;
            // Update index for moved registry (index + 1 for storage)
            _boundIdentityRegistriesIndex[lastRegistry] = indexToRemove + 1;
        }

        _boundIdentityRegistryAddresses.pop();

        // Clean up bound status and index mapping
        delete _boundIdentityRegistriesIndex[_identityRegistry]; // Set index back to 0
        _boundIdentityRegistries[_identityRegistry] = false;

        emit IdentityRegistryUnbound(_identityRegistry);
    }

    // --- View Functions ---
    function linkedIdentityRegistries() external view returns (address[] memory) {
        return _boundIdentityRegistryAddresses;
    }

    function storedIdentity(address _userAddress) external view returns (IIdentity) {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        return IIdentity(_identities[_userAddress].identityContract);
    }

    function storedInvestorCountry(address _userAddress) external view returns (uint16) {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        return _identities[_userAddress].country;
    }

    function getIdentityWallets() external view returns (address[] memory) {
        return _identityWallets;
    }

    // --- Internal Functions ---
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
    function _authorizeUpgrade(address newImplementation)
        internal
        override(UUPSUpgradeable)
        onlyRole(DEFAULT_ADMIN_ROLE)
    { }
}
