// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { IERC3643IdentityRegistryStorage } from "../ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IIdentity } from "../onchainid/interface/IIdentity.sol";

// --- Errors ---
error InvalidInvestorAddress();
error InvalidIdentityAddress();
error IdentityAlreadyExists(address userAddress);
error IdentityDoesNotExist(address userAddress);
error InvalidIdentityRegistryAddress();
error IdentityRegistryAlreadyBound(address registryAddress);
error IdentityRegistryNotBound(address registryAddress);

/// @title SMARTIdentityRegistryStorage
/// @notice Storage contract for identity registry data
contract SMARTIdentityRegistryStorage is IERC3643IdentityRegistryStorage, Ownable {
    // --- Storage Variables ---
    struct Identity {
        address identityContract;
        uint16 country;
        bool exists;
    }

    mapping(address => Identity) private _identities;
    address[] private _investors;
    // Mapping to store the index of each investor in the _investors array for O(1) removal
    mapping(address => uint256) private _investorIndex;

    // Mapping to track if an Identity Registry address is bound
    mapping(address => bool) private _identityRegistryBound;
    // Array to store the addresses of bound Identity Registries
    address[] private _boundRegistryAddresses;
    // Mapping to store the index of each bound registry in the _boundRegistryAddresses array for O(1) removal
    mapping(address => uint256) private _boundRegistryIndex;

    // --- Events ---
    event IdentityStored(address indexed _investor, IIdentity indexed _identity);
    event IdentityUnstored(address indexed _investor, IIdentity indexed _identity);
    event IdentityModified(IIdentity indexed _oldIdentity, IIdentity indexed _newIdentity);
    event CountryModified(address indexed _investor, uint16 _country);
    event IdentityRegistryBound(address indexed _identityRegistry);
    event IdentityRegistryUnbound(address indexed _identityRegistry);

    // --- Constructor ---
    constructor() Ownable(msg.sender) { }

    // --- State-Changing Functions ---
    /// @inheritdoc IERC3643IdentityRegistryStorage
    function addIdentityToStorage(address _userAddress, IIdentity _identity, uint16 _country) external onlyOwner {
        if (_userAddress == address(0)) revert InvalidInvestorAddress();
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();
        if (_identities[_userAddress].exists) revert IdentityAlreadyExists(_userAddress);

        _identities[_userAddress] = Identity(address(_identity), _country, true);
        _investors.push(_userAddress);
        // Store the index of the newly added investor
        _investorIndex[_userAddress] = _investors.length - 1;

        emit IdentityStored(_userAddress, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function removeIdentityFromStorage(address _userAddress) external onlyOwner {
        if (!_identities[_userAddress].exists) revert IdentityDoesNotExist(_userAddress);
        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);

        // Efficiently remove from _investors array using the mapping index pattern
        uint256 indexToRemove = _investorIndex[_userAddress];
        address lastInvestor = _investors[_investors.length - 1];

        // Move the last investor to the position of the one being removed
        _investors[indexToRemove] = lastInvestor;
        // Update the index mapping for the moved investor
        _investorIndex[lastInvestor] = indexToRemove;

        // Remove the last element (which is now duplicated at indexToRemove or is the one to remove if it was the last)
        _investors.pop();

        // Clean up identity data and index mapping
        delete _identities[_userAddress];
        delete _investorIndex[_userAddress];

        emit IdentityUnstored(_userAddress, oldIdentity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function modifyStoredIdentity(address _userAddress, IIdentity _identity) external onlyOwner {
        if (!_identities[_userAddress].exists) revert IdentityDoesNotExist(_userAddress);
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();

        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);
        _identities[_userAddress].identityContract = address(_identity);

        emit IdentityModified(oldIdentity, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function modifyStoredInvestorCountry(address _userAddress, uint16 _country) external onlyOwner {
        if (!_identities[_userAddress].exists) revert IdentityDoesNotExist(_userAddress);

        _identities[_userAddress].country = _country;

        emit CountryModified(_userAddress, _country);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function bindIdentityRegistry(address _identityRegistry) external onlyOwner {
        if (_identityRegistry == address(0)) revert InvalidIdentityRegistryAddress();
        if (_identityRegistryBound[_identityRegistry]) revert IdentityRegistryAlreadyBound(_identityRegistry);

        _identityRegistryBound[_identityRegistry] = true;
        _boundRegistryAddresses.push(_identityRegistry);
        _boundRegistryIndex[_identityRegistry] = _boundRegistryAddresses.length - 1;

        emit IdentityRegistryBound(_identityRegistry);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function unbindIdentityRegistry(address _identityRegistry) external onlyOwner {
        if (!_identityRegistryBound[_identityRegistry]) revert IdentityRegistryNotBound(_identityRegistry);

        // Efficiently remove from _boundRegistryAddresses array
        uint256 indexToRemove = _boundRegistryIndex[_identityRegistry];
        address lastRegistry = _boundRegistryAddresses[_boundRegistryAddresses.length - 1];

        _boundRegistryAddresses[indexToRemove] = lastRegistry;
        _boundRegistryIndex[lastRegistry] = indexToRemove;

        _boundRegistryAddresses.pop();

        // Clean up bound status and index mapping
        delete _boundRegistryIndex[_identityRegistry];
        _identityRegistryBound[_identityRegistry] = false; // Explicitly set to false

        emit IdentityRegistryUnbound(_identityRegistry);
    }

    // --- View Functions ---
    /// @inheritdoc IERC3643IdentityRegistryStorage
    function linkedIdentityRegistries() external view returns (address[] memory) {
        // Return the correctly maintained list of bound registry addresses
        return _boundRegistryAddresses;
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function storedIdentity(address _userAddress) external view returns (IIdentity) {
        if (!_identities[_userAddress].exists) revert IdentityDoesNotExist(_userAddress);
        return IIdentity(_identities[_userAddress].identityContract);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function storedInvestorCountry(address _userAddress) external view returns (uint16) {
        if (!_identities[_userAddress].exists) revert IdentityDoesNotExist(_userAddress);
        return _identities[_userAddress].country;
    }

    /// @notice Get all registered investors
    /// @return The array of investor addresses
    function getInvestors() external view returns (address[] memory) {
        return _investors;
    }
}
