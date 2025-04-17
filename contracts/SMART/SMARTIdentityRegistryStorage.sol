// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { IERC3643IdentityRegistryStorage } from "../ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
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
/// @notice Storage contract for identity registry data
contract SMARTIdentityRegistryStorage is IERC3643IdentityRegistryStorage, Ownable {
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

    // --- Modifiers ---
    // TODO: Can this be done with AccessControl?
    modifier onlyOwnerOrBoundRegistry() {
        if (msg.sender != owner() && !_boundIdentityRegistries[msg.sender]) revert UnauthorizedCaller();
        _;
    }

    // --- Constructor ---
    constructor() Ownable(msg.sender) { }

    // --- State-Changing Functions ---
    /// @inheritdoc IERC3643IdentityRegistryStorage
    function addIdentityToStorage(
        address _userAddress,
        IIdentity _identity,
        uint16 _country
    )
        external
        onlyOwnerOrBoundRegistry
    {
        if (_userAddress == address(0)) revert InvalidIdentityWalletAddress();
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();
        if (_identities[_userAddress].identityContract != address(0)) revert IdentityAlreadyExists(_userAddress);

        _identities[_userAddress] = Identity(address(_identity), _country);
        _identityWallets.push(_userAddress);
        // Store the index of the newly added wallet address
        _identityWalletsIndex[_userAddress] = _identityWallets.length - 1;

        emit IdentityStored(_userAddress, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function removeIdentityFromStorage(address _userAddress) external onlyOwnerOrBoundRegistry {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);

        // Efficiently remove from _identityWallets array using the mapping index pattern
        uint256 indexToRemove = _identityWalletsIndex[_userAddress];
        address lastWalletAddress = _identityWallets[_identityWallets.length - 1];

        // Move the last wallet address to the position of the one being removed
        _identityWallets[indexToRemove] = lastWalletAddress;
        // Update the index mapping for the moved wallet address
        _identityWalletsIndex[lastWalletAddress] = indexToRemove;

        // Remove the last element (which is now duplicated at indexToRemove or is the one to remove if it was the last)
        _identityWallets.pop();

        // Clean up identity data and index mapping
        delete _identities[_userAddress];
        delete _identityWalletsIndex[_userAddress];

        emit IdentityUnstored(_userAddress, oldIdentity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function modifyStoredIdentity(address _userAddress, IIdentity _identity) external onlyOwnerOrBoundRegistry {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();

        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);
        _identities[_userAddress].identityContract = address(_identity);

        emit IdentityModified(oldIdentity, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function modifyStoredInvestorCountry(address _userAddress, uint16 _country) external onlyOwnerOrBoundRegistry {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);

        _identities[_userAddress].country = _country;

        emit CountryModified(_userAddress, _country);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function bindIdentityRegistry(address _identityRegistry) external onlyOwner {
        if (_identityRegistry == address(0)) revert InvalidIdentityRegistryAddress();
        if (_boundIdentityRegistries[_identityRegistry]) revert IdentityRegistryAlreadyBound(_identityRegistry);

        _boundIdentityRegistries[_identityRegistry] = true;
        _boundIdentityRegistryAddresses.push(_identityRegistry);
        _boundIdentityRegistriesIndex[_identityRegistry] = _boundIdentityRegistryAddresses.length - 1;

        emit IdentityRegistryBound(_identityRegistry);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function unbindIdentityRegistry(address _identityRegistry) external onlyOwner {
        if (!_boundIdentityRegistries[_identityRegistry]) revert IdentityRegistryNotBound(_identityRegistry);

        // Efficiently remove from _boundIdentityRegistryAddresses array
        uint256 indexToRemove = _boundIdentityRegistriesIndex[_identityRegistry];
        address lastRegistry = _boundIdentityRegistryAddresses[_boundIdentityRegistryAddresses.length - 1];

        _boundIdentityRegistryAddresses[indexToRemove] = lastRegistry;
        _boundIdentityRegistriesIndex[lastRegistry] = indexToRemove;

        _boundIdentityRegistryAddresses.pop();

        // Clean up bound status and index mapping
        delete _boundIdentityRegistriesIndex[_identityRegistry];
        _boundIdentityRegistries[_identityRegistry] = false; // Explicitly set to false

        emit IdentityRegistryUnbound(_identityRegistry);
    }

    // --- View Functions ---
    /// @inheritdoc IERC3643IdentityRegistryStorage
    function linkedIdentityRegistries() external view returns (address[] memory) {
        // Return the correctly maintained list of bound registry addresses
        return _boundIdentityRegistryAddresses;
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function storedIdentity(address _userAddress) external view returns (IIdentity) {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        return IIdentity(_identities[_userAddress].identityContract);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function storedInvestorCountry(address _userAddress) external view returns (uint16) {
        if (_identities[_userAddress].identityContract == address(0)) revert IdentityDoesNotExist(_userAddress);
        return _identities[_userAddress].country;
    }

    /// @notice Get all registered wallet addresses that have an identity
    /// @return The array of wallet addresses with identities
    function getIdentityWallets() external view returns (address[] memory) {
        return _identityWallets;
    }
}
