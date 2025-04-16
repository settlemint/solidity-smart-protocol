// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { IERC3643IdentityRegistryStorage } from "../ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IIdentity } from "../onchainid/interface/IIdentity.sol";

/// @title SMARTIdentityRegistryStorage
/// @notice Storage contract for identity registry data
contract SMARTIdentityRegistryStorage is IERC3643IdentityRegistryStorage, Ownable {
    /// Storage
    struct Identity {
        address identityContract;
        uint16 country;
        bool exists;
    }

    mapping(address => Identity) private _identities;
    address[] private _investors;
    mapping(address => bool) private _identityRegistryBound;

    /// Events
    event IdentityStored(address indexed _investor, IIdentity indexed _identity);
    event IdentityUnstored(address indexed _investor, IIdentity indexed _identity);
    event IdentityModified(IIdentity indexed _oldIdentity, IIdentity indexed _newIdentity);
    event CountryModified(address indexed _investor, uint16 _country);
    event IdentityRegistryBound(address indexed _identityRegistry);
    event IdentityRegistryUnbound(address indexed _identityRegistry);

    constructor() Ownable(msg.sender) { }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function addIdentityToStorage(address _userAddress, IIdentity _identity, uint16 _country) external onlyOwner {
        require(_userAddress != address(0), "Invalid investor address");
        require(address(_identity) != address(0), "Invalid identity address");
        require(!_identities[_userAddress].exists, "Identity already exists");

        _identities[_userAddress] = Identity(address(_identity), _country, true);
        _investors.push(_userAddress);

        emit IdentityStored(_userAddress, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function removeIdentityFromStorage(address _userAddress) external onlyOwner {
        require(_identities[_userAddress].exists, "Identity does not exist");
        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);
        delete _identities[_userAddress];

        // Remove from investors array
        for (uint256 i = 0; i < _investors.length; i++) {
            if (_investors[i] == _userAddress) {
                _investors[i] = _investors[_investors.length - 1];
                _investors.pop();
                break;
            }
        }

        emit IdentityUnstored(_userAddress, oldIdentity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function modifyStoredIdentity(address _userAddress, IIdentity _identity) external onlyOwner {
        require(_identities[_userAddress].exists, "Identity does not exist");
        require(address(_identity) != address(0), "Invalid identity address");

        IIdentity oldIdentity = IIdentity(_identities[_userAddress].identityContract);
        _identities[_userAddress].identityContract = address(_identity);

        emit IdentityModified(oldIdentity, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function modifyStoredInvestorCountry(address _userAddress, uint16 _country) external onlyOwner {
        require(_identities[_userAddress].exists, "Identity does not exist");

        _identities[_userAddress].country = _country;

        emit CountryModified(_userAddress, _country);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function bindIdentityRegistry(address _identityRegistry) external onlyOwner {
        require(_identityRegistry != address(0), "Invalid identity registry");
        require(!_identityRegistryBound[_identityRegistry], "Identity registry already bound");
        _identityRegistryBound[_identityRegistry] = true;
        emit IdentityRegistryBound(_identityRegistry);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function unbindIdentityRegistry(address _identityRegistry) external onlyOwner {
        require(_identityRegistryBound[_identityRegistry], "Identity registry not bound");
        _identityRegistryBound[_identityRegistry] = false;
        emit IdentityRegistryUnbound(_identityRegistry);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function linkedIdentityRegistries() external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < _investors.length; i++) {
            if (_identityRegistryBound[_investors[i]]) {
                count++;
            }
        }

        address[] memory registries = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < _investors.length; i++) {
            if (_identityRegistryBound[_investors[i]]) {
                registries[index] = _investors[i];
                index++;
            }
        }
        return registries;
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function storedIdentity(address _userAddress) external view returns (IIdentity) {
        require(_identities[_userAddress].exists, "Identity does not exist");
        return IIdentity(_identities[_userAddress].identityContract);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function storedInvestorCountry(address _userAddress) external view returns (uint16) {
        require(_identities[_userAddress].exists, "Identity does not exist");
        return _identities[_userAddress].country;
    }

    /// @notice Get all registered investors
    /// @return The array of investor addresses
    function getInvestors() external view returns (address[] memory) {
        return _investors;
    }
}
