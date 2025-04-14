// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISmartIdentityRegistry } from "./interface/ISmartIdentityRegistry.sol";
import { IIdentity } from "./onchainid/interface/IIdentity.sol";
import { IERC3643IdentityRegistryStorage } from "../contracts/ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { IERC3643TrustedIssuersRegistry } from "../contracts/ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title SMARTIdentityRegistry
/// @notice Registry for managing investor identities
contract SMARTIdentityRegistry is ISmartIdentityRegistry, Ownable {
    /// Storage
    IERC3643IdentityRegistryStorage private _identityStorage;
    IERC3643TrustedIssuersRegistry private _trustedIssuersRegistry;

    /// Events
    event IdentityStorageSet(address indexed _identityStorage);
    event TrustedIssuersRegistrySet(address indexed _trustedIssuersRegistry);
    event IdentityRegistered(address indexed _investorAddress, IIdentity indexed _identity);
    event IdentityRemoved(address indexed _investorAddress, IIdentity indexed _identity);
    event IdentityUpdated(IIdentity indexed _oldIdentity, IIdentity indexed _newIdentity);
    event CountryUpdated(address indexed _investorAddress, uint16 indexed _country);

    constructor(address identityStorage_, address trustedIssuersRegistry_) Ownable(msg.sender) {
        _identityStorage = IERC3643IdentityRegistryStorage(identityStorage_);
        _trustedIssuersRegistry = IERC3643TrustedIssuersRegistry(trustedIssuersRegistry_);
    }

    /// @inheritdoc ISmartIdentityRegistry
    function setIdentityRegistryStorage(address _identityStorage) external override onlyOwner {
        require(_identityStorage != address(0), "Invalid storage address");
        _identityStorage = IERC3643IdentityRegistryStorage(_identityStorage);
        emit IdentityStorageSet(_identityStorage);
    }

    /// @inheritdoc ISmartIdentityRegistry
    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external override onlyOwner {
        require(_trustedIssuersRegistry != address(0), "Invalid registry address");
        _trustedIssuersRegistry = IERC3643TrustedIssuersRegistry(_trustedIssuersRegistry);
        emit TrustedIssuersRegistrySet(_trustedIssuersRegistry);
    }

    /// @inheritdoc ISmartIdentityRegistry
    function registerIdentity(address _userAddress, IIdentity _identity, uint16 _country) external override onlyOwner {
        require(_userAddress != address(0), "Invalid user address");
        require(address(_identity) != address(0), "Invalid identity address");
        require(!_identityStorage.contains(_userAddress), "Identity already registered");

        _identityStorage.addIdentityToStorage(_userAddress, address(_identity), _country);
        emit IdentityRegistered(_userAddress, _identity);
    }

    /// @inheritdoc ISmartIdentityRegistry
    function deleteIdentity(address _userAddress) external override onlyOwner {
        require(_identityStorage.contains(_userAddress), "Identity not registered");

        IIdentity identity = IIdentity(_identityStorage.getStoredIdentity(_userAddress));
        _identityStorage.removeIdentityFromStorage(_userAddress);

        emit IdentityRemoved(_userAddress, identity);
    }

    /// @inheritdoc ISmartIdentityRegistry
    function updateCountry(address _userAddress, uint16 _country) external override onlyOwner {
        require(_identityStorage.contains(_userAddress), "Identity not registered");

        _identityStorage.modifyStoredInvestorCountry(_userAddress, _country);
        emit CountryUpdated(_userAddress, _country);
    }

    /// @inheritdoc ISmartIdentityRegistry
    function updateIdentity(address _userAddress, IIdentity _identity) external override onlyOwner {
        require(_identityStorage.contains(_userAddress), "Identity not registered");
        require(address(_identity) != address(0), "Invalid identity address");

        IIdentity oldIdentity = IIdentity(_identityStorage.getStoredIdentity(_userAddress));
        _identityStorage.modifyStoredIdentity(_userAddress, address(_identity));

        emit IdentityUpdated(oldIdentity, _identity);
    }

    /// @inheritdoc ISmartIdentityRegistry
    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    )
        external
        override
        onlyOwner
    {
        require(
            _userAddresses.length == _identities.length && _identities.length == _countries.length, "Length mismatch"
        );

        for (uint256 i = 0; i < _userAddresses.length; i++) {
            registerIdentity(_userAddresses[i], _identities[i], _countries[i]);
        }
    }

    /// @inheritdoc ISmartIdentityRegistry
    function contains(address _userAddress) external view override returns (bool) {
        return _identityStorage.contains(_userAddress);
    }

    /// @inheritdoc ISmartIdentityRegistry
    function isVerified(address _userAddress, address _token) external view override returns (bool) {
        if (!_identityStorage.contains(_userAddress)) return false;

        IIdentity identity = IIdentity(_identityStorage.getStoredIdentity(_userAddress));
        address[] memory issuers = _trustedIssuersRegistry.getTrustedIssuers();

        for (uint256 i = 0; i < issuers.length; i++) {
            uint256[] memory claimTopics = _trustedIssuersRegistry.getTrustedIssuerClaimTopics(issuers[i]);
            for (uint256 j = 0; j < claimTopics.length; j++) {
                if (identity.hasClaim(issuers[i], claimTopics[j])) {
                    return true;
                }
            }
        }

        return false;
    }

    /// @inheritdoc ISmartIdentityRegistry
    function identity(address _userAddress) external view override returns (IIdentity) {
        require(_identityStorage.contains(_userAddress), "Identity not registered");
        return IIdentity(_identityStorage.getStoredIdentity(_userAddress));
    }

    /// @inheritdoc ISmartIdentityRegistry
    function investorCountry(address _userAddress) external view override returns (uint16) {
        require(_identityStorage.contains(_userAddress), "Identity not registered");
        return _identityStorage.getStoredInvestorCountry(_userAddress);
    }

    /// @inheritdoc ISmartIdentityRegistry
    function identityStorage() external view override returns (IERC3643IdentityRegistryStorage) {
        return _identityStorage;
    }

    /// @inheritdoc ISmartIdentityRegistry
    function issuersRegistry() external view override returns (IERC3643TrustedIssuersRegistry) {
        return _trustedIssuersRegistry;
    }
}
