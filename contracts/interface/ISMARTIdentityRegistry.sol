// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// OnchainID imports
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";

// Interface imports
import { ISMARTIdentityRegistryStorage } from "./ISMARTIdentityRegistryStorage.sol";
import { IERC3643TrustedIssuersRegistry } from "./ERC-3643/IERC3643TrustedIssuersRegistry.sol";
import { ISMARTTopicSchemeRegistry } from "../system/topic-scheme-registry/ISMARTTopicSchemeRegistry.sol";

/// @title ISMARTIdentityRegistry Interface
/// @author SettleMint
/// @notice This interface defines the standard functions for an Identity Registry contract within the SMART protocol.
///         It is designed to be compatible with ERC-3643 (Tokenized Asset Standard) and OnchainID.
///         The primary role of this registry is to manage the crucial link between an investor's wallet address,
///         their decentralized on-chain Identity contract (implementing `IIdentity`), and their verification status
///         based on claims issued by trusted entities.
/// @dev This registry acts as a central point of truth for associating wallet addresses with digital identities.
///      It relies on two other key components:
///      1. `ISMARTIdentityRegistryStorage`: A separate contract responsible for storing the actual mappings
///         between investor addresses, identity contracts, and country codes. This separation of concerns allows
///         for upgradability and different storage strategies.
///      2. `IERC3643TrustedIssuersRegistry`: A contract that maintains a list of trusted entities (claim issuers)
///         whose attestations (claims) about an identity are considered valid.
///      Operations like registering a new identity or checking if an identity is verified are performed through this
/// interface.
/// This interface extends IERC165 for interface detection support.
interface ISMARTIdentityRegistry is IERC165 {
    // --- Events ---

    /// @notice Emitted when the address of the `IdentityRegistryStorage` contract is successfully set or updated.
    /// @dev This event is crucial for transparency, allowing external observers to track changes in the underlying
    ///      storage mechanism used by the Identity Registry.
    /// @param sender The address of the account (typically the owner or an admin) that initiated this change.
    /// @param _identityStorage The new address of the contract implementing `ISMARTIdentityRegistryStorage`.
    event IdentityStorageSet(address indexed sender, address indexed _identityStorage);

    /// @notice Emitted when the address of the `TrustedIssuersRegistry` contract is successfully set or updated.
    /// @dev This event signals a change in the list of authorities whose claims are recognized by this Identity
    /// Registry.
    ///      It's important for users and relying parties to be aware of which issuers are trusted.
    /// @param sender The address of the account (typically the owner or an admin) that initiated this change.
    /// @param _trustedIssuersRegistry The new address of the contract implementing `IERC3643TrustedIssuersRegistry`.
    event TrustedIssuersRegistrySet(address indexed sender, address indexed _trustedIssuersRegistry);

    /// @notice Emitted when the address of the `TopicSchemeRegistry` contract is successfully set or updated.
    /// @dev This event signals a change in the topic scheme registry that defines valid claim topics.
    /// @param sender The address of the account (typically the owner or an admin) that initiated this change.
    /// @param _topicSchemeRegistry The new address of the contract implementing `ISMARTTopicSchemeRegistry`.
    event TopicSchemeRegistrySet(address indexed sender, address indexed _topicSchemeRegistry);

    /// @notice Emitted when a new identity is successfully registered for an investor's wallet address.
    /// @dev This event marks the creation of an association between a wallet and an on-chain identity contract.
    /// @param sender The address of the account (e.g., a registrar agent) that performed the registration.
    /// @param _investorAddress The wallet address of the investor being registered.
    /// @param _identity The address of the investor's `IIdentity` smart contract, which holds their claims and
    /// attestations.
    /// @param _country The numeric country code (ISO 3166-1 alpha-2 standard) representing the investor's jurisdiction.
    event IdentityRegistered(
        address indexed sender, address indexed _investorAddress, IIdentity indexed _identity, uint16 _country
    );

    /// @notice Emitted when an existing identity registration is successfully removed for an investor's wallet address.
    /// @dev This event indicates that the link between a wallet address and its associated `IIdentity` contract has
    /// been severed.
    /// @param sender The address of the account (e.g., a registrar agent) that performed the removal.
    /// @param _investorAddress The wallet address of the investor whose registration was removed.
    /// @param _identity The address of the `IIdentity` smart contract that was previously associated with the investor
    /// address.
    event IdentityRemoved(address indexed sender, address indexed _investorAddress, IIdentity indexed _identity);

    /// @notice Emitted when the `IIdentity` contract associated with a registered investor's wallet address is updated.
    /// @dev This typically occurs during identity recovery processes or when an investor chooses to link a new identity
    /// contract.
    /// @param sender The address of the account (e.g., a registrar agent) that performed the update.
    /// @param _oldIdentity The address of the previously associated `IIdentity` contract.
    /// @param _newIdentity The address of the newly associated `IIdentity` contract.
    event IdentityUpdated(address indexed sender, IIdentity indexed _oldIdentity, IIdentity indexed _newIdentity);

    /// @notice Emitted when the country code associated with a registered investor's wallet address is updated.
    /// @dev This event is important for compliance processes that may depend on the investor's jurisdiction.
    /// @param sender The address of the account (e.g., a registrar agent) that performed the update.
    /// @param _investorAddress The wallet address of the investor whose country information was updated.
    /// @param _country The new numeric country code (conforming to ISO 3166-1 alpha-2 standard, e.g., 840 for USA).
    event CountryUpdated(address indexed sender, address indexed _investorAddress, uint16 indexed _country);

    /// @notice Emitted when an identity is successfully recovered, associating it with a new wallet
    ///         and marking the old wallet as lost.
    /// @param sender The address of the account (e.g., a registrar agent) that performed the recovery.
    /// @param identityContract The IIdentity contract whose associated wallet was recovered. (Indexed)
    /// @param newWallet The new active wallet address for the identity. (Indexed)
    /// @param oldLostWallet The previous wallet address that has now been marked as lost. (Indexed)
    event IdentityRecovered(
        address indexed sender, IIdentity indexed identityContract, address indexed newWallet, address oldLostWallet
    );

    // --- Configuration Setters (Typically Owner/Admin Restricted) ---

    /**
     * @notice Sets or updates the address of the `IdentityRegistryStorage` contract.
     * @dev This function is usually restricted to an administrative role (e.g., contract owner).
     *      It allows the Identity Registry to delegate the actual storage of identity data to a separate, potentially
     * upgradable, contract.
     *      Changing this address can have significant implications, so it must be handled with care.
     * @param _identityRegistryStorage The address of the new contract that implements the
     * `ISMARTIdentityRegistryStorage` interface.
     * @custom:emit IdentityStorageSet
     */
    function setIdentityRegistryStorage(address _identityRegistryStorage) external;

    /**
     * @notice Sets or updates the address of the `TrustedIssuersRegistry` contract.
     * @dev This function is usually restricted to an administrative role (e.g., contract owner).
     *      The `TrustedIssuersRegistry` is responsible for maintaining a list of claim issuers whose attestations are
     * considered valid.
     *      Updating this address changes the set of authorities recognized for identity verification.
     * @param _trustedIssuersRegistry The address of the new contract that implements the
     * `IERC3643TrustedIssuersRegistry` interface.
     * @custom:emit TrustedIssuersRegistrySet
     */
    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external;

    /**
     * @notice Sets or updates the address of the `TopicSchemeRegistry` contract.
     * @dev This function is usually restricted to an administrative role (e.g., contract owner).
     *      The `TopicSchemeRegistry` is responsible for maintaining valid claim topic schemes.
     *      Updating this address changes which claim topics are considered valid for verification.
     * @param _topicSchemeRegistry The address of the new contract that implements the
     * `ISMARTTopicSchemeRegistry` interface.
     * @custom:emit TopicSchemeRegistrySet
     */
    function setTopicSchemeRegistry(address _topicSchemeRegistry) external;

    // --- Identity Management (Typically Agent/Registrar Role Restricted) ---

    /**
     * @notice Registers an investor's wallet address, linking it to their on-chain `IIdentity` contract and their
     * country of residence.
     * @dev This function is typically callable only by authorized agents or registrars.
     *      It will usually revert if the provided `_userAddress` is already registered to prevent duplicate entries.
     *      The country code is important for jurisdictional compliance.
     * @param _userAddress The investor's primary wallet address (externally owned account or smart contract wallet).
     * @param _identity The address of the investor's deployed `IIdentity` contract, which manages their claims.
     * @param _country The numeric country code (ISO 3166-1 alpha-2 standard) representing the investor's jurisdiction.
     * @custom:emit IdentityRegistered
     */
    function registerIdentity(address _userAddress, IIdentity _identity, uint16 _country) external;

    /**
     * @notice Removes an existing identity registration for an investor's wallet address.
     * @dev This function is typically callable only by authorized agents or registrars.
     *      It will usually revert if the `_userAddress` is not currently registered.
     *      This action effectively unlinks the wallet address from its associated `IIdentity` contract in this
     * registry.
     * @param _userAddress The investor's wallet address whose registration is to be removed.
     * @custom:emit IdentityRemoved
     */
    function deleteIdentity(address _userAddress) external;

    /**
     * @notice Updates the country code associated with a previously registered investor's wallet address.
     * @dev This function is typically callable only by authorized agents or registrars.
     *      It will usually revert if the `_userAddress` is not registered.
     *      This is used to reflect changes in an investor's country of residence for compliance purposes.
     * @param _userAddress The investor's wallet address whose country information needs updating.
     * @param _country The new numeric country code (ISO 3166-1 alpha-2 standard).
     * @custom:emit CountryUpdated
     */
    function updateCountry(address _userAddress, uint16 _country) external;

    /**
     * @notice Updates the on-chain `IIdentity` contract associated with a previously registered investor's wallet
     * address.
     * @dev This function is typically callable only by authorized agents or registrars.
     *      It will usually revert if the `_userAddress` is not registered.
     *      This is useful for scenarios like identity recovery, or if an investor upgrades or changes their `IIdentity`
     * contract.
     * @param _userAddress The investor's wallet address whose associated `IIdentity` contract needs updating.
     * @param _identity The address of the investor's new `IIdentity` contract.
     * @custom:emit IdentityUpdated
     */
    function updateIdentity(address _userAddress, IIdentity _identity) external;

    /**
     * @notice Registers multiple identities in a single batch transaction.
     * @dev This function is typically callable only by authorized agents or registrars.
     *      It is a gas-saving measure for registering many users at once.
     *      The function will usually revert if any of the `_userAddresses` are already registered or if the input
     * arrays have mismatched lengths.
     *      Care should be taken with the number of entries due to block gas limits.
     * @param _userAddresses An array of investor wallet addresses to be registered.
     * @param _identities An array of corresponding `IIdentity` contract addresses for each investor.
     * @param _countries An array of corresponding numeric country codes (ISO 3166-1 alpha-2) for each investor.
     * @custom:emit Multiple `IdentityRegistered` events, one for each successful registration.
     */
    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    )
        external;

    /// @notice Recovers an identity by associating an existing IIdentity contract with a new wallet address,
    ///         and marking the old wallet address as lost.
    /// @dev This function is typically restricted to registrar roles.
    ///      It ensures the old wallet was indeed linked to the given identity and is not already lost.
    ///      The new wallet must not be in use or marked as lost.
    ///      The country code from the old wallet registration will be preserved for the new wallet.
    /// @param identityContract The IIdentity contract to be associated with the new wallet.
    /// @param newWallet The new wallet address to activate for the identity.
    /// @param oldLostWallet The current wallet address associated with the identity that will be marked as lost.
    function recoverIdentity(IIdentity identityContract, address newWallet, address oldLostWallet) external;

    // --- Registry Consultation (View Functions) ---

    /**
     * @notice Checks if a given investor wallet address is currently registered in this Identity Registry.
     * @dev This is a view function and does not consume gas beyond the read operation cost.
     * @param _userAddress The wallet address to query.
     * @return `true` if the address is registered, `false` otherwise.
     */
    function contains(address _userAddress) external view returns (bool);

    /**
     * @notice Checks if a registered investor's wallet address is considered 'verified'.
     * @dev Verification is determined by checking the claims held in the investor's associated `IIdentity` contract.
     *      Specifically, it checks if the `IIdentity` contract has valid claims for ALL topics listed in
     * `requiredClaimTopics`.
     *      A claim is considered valid if it is issued by an issuer listed in the `TrustedIssuersRegistry` and has not
     * expired or been revoked.
     *      This function typically interacts with both the `IIdentity` contract and the `TrustedIssuersRegistry`.
     * @param _userAddress The investor's wallet address to verify.
     * @param requiredClaimTopics An array of claim topic IDs (e.g., KYC, accreditation) that the identity must possess.
     * @return `true` if the investor's identity holds all required valid claims, `false` otherwise.
     */
    function isVerified(address _userAddress, uint256[] memory requiredClaimTopics) external view returns (bool);

    /**
     * @notice Retrieves the `IIdentity` contract address associated with a registered investor's wallet address.
     * @dev This is a view function. It will typically revert if the `_userAddress` is not registered.
     * @param _userAddress The investor's wallet address.
     * @return The address of the `IIdentity` contract linked to the given wallet address.
     */
    function identity(address _userAddress) external view returns (IIdentity);

    /**
     * @notice Retrieves the numeric country code associated with a registered investor's wallet address.
     * @dev This is a view function. It will typically revert if the `_userAddress` is not registered.
     * @param _userAddress The investor's wallet address.
     * @return The numeric country code (ISO 3166-1 alpha-2) for the investor's jurisdiction.
     */
    function investorCountry(address _userAddress) external view returns (uint16);

    // --- Component Getters (View Functions) ---

    /**
     * @notice Returns the address of the `IdentityRegistryStorage` contract currently being used by this Identity
     * Registry.
     * @dev This allows external parties to inspect which storage contract is active.
     * @return The address of the contract implementing `ISMARTIdentityRegistryStorage`.
     */
    function identityStorage() external view returns (ISMARTIdentityRegistryStorage);

    /**
     * @notice Returns the address of the `TrustedIssuersRegistry` contract currently being used by this Identity
     * Registry.
     * @dev This allows external parties to inspect which trusted issuers list is active for verification purposes.
     * @return The address of the contract implementing `IERC3643TrustedIssuersRegistry`.
     */
    function issuersRegistry() external view returns (IERC3643TrustedIssuersRegistry);

    /**
     * @notice Returns the address of the `TopicSchemeRegistry` contract currently being used by this Identity
     * Registry.
     * @dev This allows external parties to inspect which topic scheme registry is active for validation.
     * @return The address of the contract implementing `ISMARTTopicSchemeRegistry`.
     */
    function topicSchemeRegistry() external view returns (ISMARTTopicSchemeRegistry);

    // --- Lost Wallet View Functions ---

    /// @notice Checks if a wallet address has been marked as lost.
    /// @param userWallet The wallet address to check.
    /// @return True if the wallet is marked as lost, false otherwise.
    function isWalletLost(address userWallet) external view returns (bool);

    /// @notice Checks if a wallet address has been marked as lost for a specific IIdentity contract.
    /// @param identityContract The IIdentity contract.
    /// @param userWallet The wallet address to check.
    /// @return True if the wallet is marked as lost for the identity, false otherwise.
    function isWalletLostForIdentity(IIdentity identityContract, address userWallet) external view returns (bool);

    /// @notice Retrieves all wallet addresses that have been marked as lost for a specific IIdentity contract.
    /// @param identityContract The IIdentity contract.
    /// @return An array of lost wallet addresses.
    function getLostWalletsForIdentity(IIdentity identityContract) external view returns (address[] memory);
}
