// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMARTIdentityRegistry } from "./interface/ISMARTIdentityRegistry.sol";
import { IIdentity } from "./../onchainid/interface/IIdentity.sol";
import { IERC3643IdentityRegistryStorage } from "./../ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { IERC3643TrustedIssuersRegistry } from "./../ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { ISMART } from "./interface/ISMART.sol";
import { IClaimIssuer } from "./../onchainid/interface/IClaimIssuer.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// --- Errors ---
error InvalidStorageAddress();
error InvalidRegistryAddress();
error IdentityNotRegistered(address userAddress);
error InvalidIdentityAddress();
error ArrayLengthMismatch();
error InvalidUserAddress();
error IdentityAlreadyRegistered(address userAddress);

/// @title SMARTIdentityRegistry
/// @notice Registry for managing investor identities (Upgradeable)
contract SMARTIdentityRegistry is Initializable, ISMARTIdentityRegistry, OwnableUpgradeable, UUPSUpgradeable {
    // --- Storage ---
    IERC3643IdentityRegistryStorage private _identityStorage;
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
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract after deployment through a proxy.
    /// @param initialOwner The address to grant ownership to.
    /// @param identityStorage_ The address of the Identity Registry Storage contract.
    /// @param trustedIssuersRegistry_ The address of the Trusted Issuers Registry contract.
    function initialize(
        address initialOwner,
        address identityStorage_,
        address trustedIssuersRegistry_
    )
        public
        initializer
    {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        if (identityStorage_ == address(0)) revert InvalidStorageAddress();
        if (trustedIssuersRegistry_ == address(0)) revert InvalidRegistryAddress();

        _identityStorage = IERC3643IdentityRegistryStorage(identityStorage_);
        emit IdentityStorageSet(address(_identityStorage));
        _trustedIssuersRegistry = IERC3643TrustedIssuersRegistry(trustedIssuersRegistry_);
        emit TrustedIssuersRegistrySet(address(_trustedIssuersRegistry));
    }

    // --- State-Changing Functions ---
    /// @inheritdoc ISMARTIdentityRegistry
    function setIdentityRegistryStorage(address identityStorage_) external override onlyOwner {
        if (identityStorage_ == address(0)) revert InvalidStorageAddress();
        _identityStorage = IERC3643IdentityRegistryStorage(identityStorage_);
        emit IdentityStorageSet(address(_identityStorage));
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function setTrustedIssuersRegistry(address trustedIssuersRegistry_) external override onlyOwner {
        if (trustedIssuersRegistry_ == address(0)) revert InvalidRegistryAddress();
        _trustedIssuersRegistry = IERC3643TrustedIssuersRegistry(trustedIssuersRegistry_);
        emit TrustedIssuersRegistrySet(address(_trustedIssuersRegistry));
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function registerIdentity(address _userAddress, IIdentity _identity, uint16 _country) external override onlyOwner {
        _registerIdentity(_userAddress, _identity, _country);
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function deleteIdentity(address _userAddress) external override onlyOwner {
        if (!this.contains(_userAddress)) revert IdentityNotRegistered(_userAddress);

        IIdentity identityToDelete = IIdentity(_identityStorage.storedIdentity(_userAddress));
        _identityStorage.removeIdentityFromStorage(_userAddress);

        emit IdentityRemoved(_userAddress, identityToDelete);
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function updateCountry(address _userAddress, uint16 _country) external override onlyOwner {
        if (!this.contains(_userAddress)) revert IdentityNotRegistered(_userAddress);

        _identityStorage.modifyStoredInvestorCountry(_userAddress, _country);
        emit CountryUpdated(_userAddress, _country);
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function updateIdentity(address _userAddress, IIdentity _identity) external override onlyOwner {
        if (!this.contains(_userAddress)) revert IdentityNotRegistered(_userAddress);
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();

        IIdentity oldInvestorIdentity = IIdentity(_identityStorage.storedIdentity(_userAddress));
        _identityStorage.modifyStoredIdentity(_userAddress, _identity);

        emit IdentityUpdated(oldInvestorIdentity, _identity);
    }

    /// @inheritdoc ISMARTIdentityRegistry
    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    )
        external
        override
        onlyOwner
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
        // Attempt to retrieve the identity.
        // If storedIdentity reverts (e.g., IdentityDoesNotExist), the catch block executes.
        try _identityStorage.storedIdentity(_userAddress) {
            /* returns (IIdentity memory) */
            // Successfully retrieved the identity, so it exists.
            return true;
        } catch {
            // Failed to retrieve the identity (likely because it doesn't exist).
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
        // 1. Initial checks
        if (!this.contains(_userAddress)) return false;
        if (requiredClaimTopics.length == 0) return true;

        // 2. Get the identity contract to verify
        IIdentity identityToVerify = IIdentity(_identityStorage.storedIdentity(_userAddress));

        // 3. Iterate through each required claim topic
        for (uint256 i = 0; i < requiredClaimTopics.length; i++) {
            uint256 currentTopic = requiredClaimTopics[i];
            // Skip if topic is invalid (0) or already found (marked as 0 during processing)
            if (currentTopic == 0) continue;

            // 4. Find issuers trusted for this specific topic
            IClaimIssuer[] memory relevantIssuers = _trustedIssuersRegistry.getTrustedIssuersForClaimTopic(currentTopic);

            // 5. Check each relevant issuer for a valid claim
            for (uint256 j = 0; j < relevantIssuers.length; j++) {
                IClaimIssuer relevantIssuer = relevantIssuers[j];
                bytes32 claimId = keccak256(abi.encode(relevantIssuer, currentTopic));

                // 6. Attempt to retrieve and validate the claim from the identity
                try identityToVerify.getClaim(claimId) returns (
                    uint256 topic, // Claim's topic
                    uint256, // Claim's scheme
                    address issuer, // Issuer address stored within the claim
                    bytes memory signature, // Claim signature
                    bytes memory data, // Claim data
                    string memory // Claim URI
                ) {
                    // 6a. Verify the claim details match and the claim is valid
                    if (
                        issuer == address(relevantIssuer) && topic == currentTopic
                            && IClaimIssuer(issuer).isClaimValid(identityToVerify, topic, signature, data)
                    ) {
                        // 6b. Mark topic as found (using 0) and break inner loop (found for this topic)
                        requiredClaimTopics[i] = 0;
                        break; // Go to the next required topic (i)
                    }
                    // If claim details mismatch or claim is invalid, continue to the next relevant issuer
                } catch {
                    // If getClaim failed (claim doesn't exist for this issuer/topic), continue
                    continue; // Check next relevant issuer (j)
                }
            }

            // 7. OPTIMIZATION: Early Exit
            // If the inner loop completed without finding a valid claim for the current topic
            // (requiredClaimTopics[i] is still non-zero), verification fails immediately.
            if (requiredClaimTopics[i] != 0) {
                return false;
            }
            // Otherwise, proceed to the next required topic (i)
        }

        // 8. Final Result
        // If the loop completes without an early exit, all required topics were validated.
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

    /// @notice Internal function to register an identity
    /// @param _userAddress The address of the user
    /// @param _identity The identity contract
    /// @param _country The country code
    function _registerIdentity(address _userAddress, IIdentity _identity, uint16 _country) internal {
        if (_userAddress == address(0)) revert InvalidUserAddress();
        if (address(_identity) == address(0)) revert InvalidIdentityAddress();
        if (this.contains(_userAddress)) revert IdentityAlreadyRegistered(_userAddress);

        _identityStorage.addIdentityToStorage(_userAddress, _identity, _country);
        emit IdentityRegistered(_userAddress, _identity);
    }

    // --- Upgradeability ---

    /// @dev Authorizes an upgrade to a new implementation contract. Only the owner can authorize.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
