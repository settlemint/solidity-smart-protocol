// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { IERC3643IdentityRegistryStorage } from "../ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

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

    /// Events
    event IdentityStored(address indexed investor, address indexed identity, uint16 country);
    event IdentityRemoved(address indexed investor);
    event IdentityUpdated(address indexed investor, address indexed oldIdentity, address indexed newIdentity);
    event CountryUpdated(address indexed investor, uint16 indexed country);

    constructor() Ownable(msg.sender) { }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function addIdentityToStorage(address _investor, address _identity, uint16 _country) external override onlyOwner {
        require(_investor != address(0), "Invalid investor address");
        require(_identity != address(0), "Invalid identity address");
        require(!_identities[_investor].exists, "Identity already exists");

        _identities[_investor] = Identity(_identity, _country, true);
        _investors.push(_investor);

        emit IdentityStored(_investor, _identity, _country);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function removeIdentityFromStorage(address _investor) external override onlyOwner {
        require(_identities[_investor].exists, "Identity does not exist");

        delete _identities[_investor];
        for (uint256 i = 0; i < _investors.length; i++) {
            if (_investors[i] == _investor) {
                _investors[i] = _investors[_investors.length - 1];
                _investors.pop();
                break;
            }
        }

        emit IdentityRemoved(_investor);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function modifyStoredIdentity(address _investor, address _identity) external override onlyOwner {
        require(_identities[_investor].exists, "Identity does not exist");
        require(_identity != address(0), "Invalid identity address");

        address oldIdentity = _identities[_investor].identityContract;
        _identities[_investor].identityContract = _identity;

        emit IdentityUpdated(_investor, oldIdentity, _identity);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function modifyStoredInvestorCountry(address _investor, uint16 _country) external override onlyOwner {
        require(_identities[_investor].exists, "Identity does not exist");

        _identities[_investor].country = _country;

        emit CountryUpdated(_investor, _country);
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function getStoredIdentity(address _investor) external view override returns (address) {
        return _identities[_investor].identityContract;
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function getStoredInvestorCountry(address _investor) external view override returns (uint16) {
        return _identities[_investor].country;
    }

    /// @inheritdoc IERC3643IdentityRegistryStorage
    function contains(address _investor) external view override returns (bool) {
        return _identities[_investor].exists;
    }

    /// @notice Get all registered investors
    /// @return The array of investor addresses
    function getInvestors() external view returns (address[] memory) {
        return _investors;
    }
}
