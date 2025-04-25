// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// Interface imports
import { IIdentity } from "./../../onchainid/interface/IIdentity.sol";
import { IERC3643IdentityRegistryStorage } from "./../../ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { IERC3643TrustedIssuersRegistry } from "./../../ERC-3643/IERC3643TrustedIssuersRegistry.sol";

// --- Events ---

/// @notice Emitted when the IdentityRegistryStorage address is set or updated.
/// @param _identityStorage The address of the new Identity Registry Storage contract.
event IdentityStorageSet(address indexed _identityStorage);

/// @notice Emitted when the TrustedIssuersRegistry address is set or updated.
/// @param _trustedIssuersRegistry The address of the new Trusted Issuers Registry contract.
event TrustedIssuersRegistrySet(address indexed _trustedIssuersRegistry);

/// @notice Emitted when a new identity is registered for an investor address.
/// @param _investorAddress The address of the investor's wallet being registered.
/// @param _identity The address of the investor's Identity smart contract (onchainID).
event IdentityRegistered(address indexed _investorAddress, IIdentity indexed _identity);

/// @notice Emitted when an identity registration is removed for an investor address.
/// @param _investorAddress The address of the investor's wallet being removed.
/// @param _identity The address of the Identity smart contract that was associated.
event IdentityRemoved(address indexed _investorAddress, IIdentity indexed _identity);

/// @notice Emitted when the Identity contract associated with an investor address is updated.
/// @param _oldIdentity The address of the previous Identity contract.
/// @param _newIdentity The address of the new Identity contract.
event IdentityUpdated(IIdentity indexed _oldIdentity, IIdentity indexed _newIdentity);

/// @notice Emitted when the country associated with an investor address is updated.
/// @param _investorAddress The investor address whose country was updated.
/// @param _country The new numeric country code (ISO 3166-1 alpha-2).
event CountryUpdated(address indexed _investorAddress, uint16 indexed _country);

/// @title ISMART Identity Registry Interface
/// @notice Defines the interface for an Identity Registry compatible with SMART tokens and ERC-3643.
///         Manages the link between investor wallets, their on-chain Identity contracts, and verification status.
interface ISMARTIdentityRegistry {
    // --- Functions ---

    // -- Configuration Setters (Admin/Owner) --

    /**
     * @notice Sets or updates the address of the Identity Registry Storage contract.
     * @dev Typically restricted to the contract owner.
     * @param _identityRegistryStorage The address of the new `IERC3643IdentityRegistryStorage` implementation.
     * Emits `IdentityStorageSet` event.
     */
    function setIdentityRegistryStorage(address _identityRegistryStorage) external;

    /**
     * @notice Sets or updates the address of the Trusted Issuers Registry contract.
     * @dev Typically restricted to the contract owner.
     * @param _trustedIssuersRegistry The address of the new `IERC3643TrustedIssuersRegistry` implementation.
     * Emits `TrustedIssuersRegistrySet` event.
     */
    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external;

    // -- Identity Management (Agent/Registrar Role) --

    /**
     * @notice Registers an investor's wallet address, linking it to their on-chain Identity contract and country.
     * @dev Requires agent/registrar privileges. Reverts if the address is already registered.
     * @param _userAddress The investor's wallet address.
     * @param _identity The address of the investor's `IIdentity` contract.
     * @param _country The numeric country code (ISO 3166-1 alpha-2) of the investor.
     * Emits `IdentityRegistered` event.
     */
    function registerIdentity(address _userAddress, IIdentity _identity, uint16 _country) external;

    /**
     * @notice Removes an identity registration for an investor address.
     * @dev Requires agent/registrar privileges. Reverts if the address is not registered.
     * @param _userAddress The investor's wallet address to remove.
     * Emits `IdentityRemoved` event.
     */
    function deleteIdentity(address _userAddress) external;

    /**
     * @notice Updates the country code associated with a registered investor address.
     * @dev Requires agent/registrar privileges. Reverts if the address is not registered.
     * @param _userAddress The investor's wallet address.
     * @param _country The new numeric country code (ISO 3166-1 alpha-2).
     * Emits `CountryUpdated` event.
     */
    function updateCountry(address _userAddress, uint16 _country) external;

    /**
     * @notice Updates the on-chain Identity contract associated with a registered investor address.
     * @dev Requires agent/registrar privileges. Reverts if the address is not registered.
     *      Often used during identity recovery or updates.
     * @param _userAddress The investor's wallet address.
     * @param _identity The address of the investor's new `IIdentity` contract.
     * Emits `IdentityUpdated` event.
     */
    function updateIdentity(address _userAddress, IIdentity _identity) external;

    /**
     * @notice Registers multiple identities in a single transaction.
     * @dev Requires agent/registrar privileges. Reverts if any address is already registered.
     *      Use with caution due to potential gas limits.
     * @param _userAddresses Array of investor wallet addresses.
     * @param _identities Array of corresponding `IIdentity` contract addresses.
     * @param _countries Array of corresponding numeric country codes.
     * Emits multiple `IdentityRegistered` events.
     */
    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    )
        external;

    // -- Registry Consultation (Views) --

    /**
     * @notice Checks if an investor wallet address is registered in the registry.
     * @param _userAddress The address to check.
     * @return True if the address is registered, false otherwise.
     */
    function contains(address _userAddress) external view returns (bool);

    /**
     * @notice Checks if a registered investor address is considered verified based on required claim topics.
     * @dev Verification involves checking the associated `IIdentity` contract for valid claims
     *      matching the `requiredClaimTopics`, issued by trusted issuers listed in the `TrustedIssuersRegistry`.
     * @param _userAddress The investor address to verify.
     * @param requiredClaimTopics An array of claim topic IDs that must be present and valid.
     * @return True if the address holds all required valid claims, false otherwise.
     */
    function isVerified(address _userAddress, uint256[] memory requiredClaimTopics) external view returns (bool);

    /**
     * @notice Retrieves the `IIdentity` contract address associated with a registered investor address.
     * @param _userAddress The investor's wallet address.
     * @return The address of the associated `IIdentity` contract.
     */
    function identity(address _userAddress) external view returns (IIdentity);

    /**
     * @notice Retrieves the numeric country code associated with a registered investor address.
     * @param _userAddress The investor's wallet address.
     * @return The numeric country code (ISO 3166-1 alpha-2).
     */
    function investorCountry(address _userAddress) external view returns (uint16);

    // -- Component Getters (Views) --

    /**
     * @notice Returns the address of the currently linked Identity Registry Storage contract.
     * @return The address of the `IERC3643IdentityRegistryStorage` contract.
     */
    function identityStorage() external view returns (IERC3643IdentityRegistryStorage);

    /**
     * @notice Returns the address of the currently linked Trusted Issuers Registry contract.
     * @return The address of the `IERC3643TrustedIssuersRegistry` contract.
     */
    function issuersRegistry() external view returns (IERC3643TrustedIssuersRegistry);
}
