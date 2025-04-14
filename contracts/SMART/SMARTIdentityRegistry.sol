// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMARTIdentityRegistry } from "./interface/ISmartIdentityRegistry.sol";
import { IIdentity } from "./../onchainid/interface/IIdentity.sol";
import { IERC3643IdentityRegistryStorage } from "./../ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { IERC3643TrustedIssuersRegistry } from "./../ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { ISMART } from "./interface/ISMART.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title SMARTIdentityRegistry
/// @notice Registry for managing investor identities
contract SMARTIdentityRegistry is ISMARTIdentityRegistry, Ownable {
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
        // Check if identity exists
        if (!_identityStorage.contains(_userAddress)) return false;

        // Get the identity and required claim topics
        IIdentity identity = IIdentity(_identityStorage.getStoredIdentity(_userAddress));
        uint256[] memory requiredClaimTopics = ISMART(_token).getRequiredClaimTopics();

        // If no required claims, identity is verified
        if (requiredClaimTopics.length == 0) return true;

        // Get all trusted issuers
        address[] memory issuers = _trustedIssuersRegistry.getTrustedIssuers();

        // Cache issuer claim topics
        mapping(address => uint256[]) memory issuerClaimTopicsCache;
        for (uint256 j = 0; j < issuers.length; j++) {
            issuerClaimTopicsCache[issuers[j]] = _trustedIssuersRegistry.getTrustedIssuerClaimTopics(issuers[j]);
        }

        // For each required claim topic
        for (uint256 i = 0; i < requiredClaimTopics.length; i++) {
            bool hasRequiredClaim = false;

            // Check each trusted issuer
            for (uint256 j = 0; j < issuers.length; j++) {
                // Get cached claim topics for this issuer
                uint256[] memory issuerClaimTopics = issuerClaimTopicsCache[issuers[j]];

                // Check if this issuer is allowed to issue this claim topic
                bool issuerCanIssueClaim = false;
                for (uint256 k = 0; k < issuerClaimTopics.length; k++) {
                    if (issuerClaimTopics[k] == requiredClaimTopics[i]) {
                        issuerCanIssueClaim = true;
                        break;
                    }
                }

                if (issuerCanIssueClaim) {
                    // Calculate the claimId
                    bytes32 claimId = keccak256(abi.encode(issuers[j], requiredClaimTopics[i]));

                    // Try to get the claim
                    try identity.getClaim(claimId) returns (
                        uint256 topic,
                        uint256 scheme,
                        address issuer,
                        bytes memory signature,
                        bytes memory data,
                        string memory
                    ) {
                        // If we got here, the claim exists
                        // Verify the claim is valid
                        if (identity.isClaimValid(identity, topic, signature, data)) {
                            hasRequiredClaim = true;
                            break;
                        }
                    } catch {
                        // Claim doesn't exist, continue to next issuer
                        continue;
                    }
                }
            }

            // If any required claim is missing, identity is not verified
            if (!hasRequiredClaim) return false;
        }

        return true;
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
