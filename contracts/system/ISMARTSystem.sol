// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title ISMARTSystem Interface
/// @author SettleMint Tokenization Services
/// @notice This interface outlines the essential functions for interacting with the SMART Protocol's central system
/// contract.
/// @dev The SMART System contract serves as the main hub and discovery point for various modules and features within
/// the
/// SMART Protocol. It allows other contracts and external users to find the addresses of crucial components like
/// compliance modules, identity registries, and their corresponding proxy contracts. These proxies are important
/// because they enable these components to be upgraded in the future without altering the addresses that other parts
/// of the system use to interact with them, ensuring stability and maintainability.
interface ISMARTSystem {
    /// @notice Initializes and sets up the entire SMART Protocol system.
    /// @dev This function is responsible for the initial deployment and configuration of the SMART Protocol.
    /// This involves deploying necessary smart contracts, setting initial parameters, and defining the relationships
    /// and connections between different components of the system.
    /// It is critically important that this function is called only ONCE during the very first deployment of the
    /// protocol.
    /// Attempting to call it more than once could result in severe errors, misconfigurations, or unpredictable behavior
    /// in the protocol's operation.
    function bootstrap() external;

    /// @notice Retrieves the current, active smart contract address of the compliance module's logic.
    /// @dev Compliance modules are responsible for enforcing rules and restrictions on token transfers, account
    /// interactions,
    /// or other operations within the SMART Protocol. For example, they might check if a transfer is allowed based on
    /// regulatory requirements.
    /// This function returns the specific address of the contract that holds the actual programming code (the "logic")
    /// for these compliance checks.
    /// It's important to note that this address can change if the compliance logic is updated or upgraded to a new
    /// version.
    /// @return complianceImplementationAddress The blockchain address of the smart contract containing the compliance
    /// logic.
    function complianceImplementation() external view returns (address complianceImplementationAddress);

    /// @notice Retrieves the current, active smart contract address of the identity registry module's logic.
    /// @dev Identity registries are a core component for managing information about users, organizations, or any entity
    /// interacting with SMART tokens. This can include details like Know Your Customer (KYC) / Anti-Money Laundering
    /// (AML)
    /// status, investor qualifications, country of residence, or other relevant identity attributes.
    /// This function returns the specific address of the contract that holds the actual programming code (the "logic")
    /// for the identity registry.
    /// Similar to other modules, this address can change if the identity registry's logic is upgraded.
    /// @return identityRegistryImplementationAddress The blockchain address of the smart contract containing the
    /// identity
    /// registry logic.
    function identityRegistryImplementation() external view returns (address identityRegistryImplementationAddress);

    /// @notice Retrieves the current, active smart contract address of the identity registry storage module's logic.
    /// @dev Identity registry storage modules are dedicated to securely and efficiently storing the data associated
    /// with
    /// the identities managed by the identity registry. This separation of logic and storage can enhance security and
    /// upgradeability.
    /// This function returns the specific address of the contract that holds the actual programming code (the "logic")
    /// for managing this identity data storage.
    /// This address may change if the storage management logic is upgraded or if data is migrated to a new storage
    /// system.
    /// @return identityRegistryStorageImplementationAddress The blockchain address of the smart contract containing the
    /// identity registry storage logic.
    function identityRegistryStorageImplementation()
        external
        view
        returns (address identityRegistryStorageImplementationAddress);

    /// @notice Retrieves the current, active smart contract address of the identity factory module's logic.
    /// @dev Identity factories are responsible for the creation of new identity contracts or records within the
    /// SMART Protocol. They provide a standardized way to onboard new users or entities and associate them with
    /// an on-chain identity.
    /// This function returns the specific address of the contract that holds the actual programming code (the "logic")
    /// for this identity creation process.
    /// This address can change if the identity factory's logic is upgraded.
    /// @return identityFactoryImplementationAddress The blockchain address of the smart contract containing the
    /// identity
    /// factory logic.
    function identityFactoryImplementation() external view returns (address identityFactoryImplementationAddress);

    /// @notice Retrieves the current, active smart contract address of the trusted issuers registry module's logic.
    /// @dev Trusted issuers registries play a crucial role in decentralized identity systems. They maintain a list of
    /// entities (known as "issuers," such as KYC providers, accreditation bodies, etc.) that are authorized and trusted
    /// to make verifiable claims or attestations about identities (e.g., "User X is KYC verified," "Entity Y is an
    /// accredited investor").
    /// This function returns the specific address of the contract that holds the actual programming code (the "logic")
    /// for managing this list of trusted issuers.
    /// This address can change if the trusted issuers registry's logic is upgraded.
    /// @return trustedIssuersRegistryImplementationAddress The blockchain address of the smart contract containing the
    /// trusted issuers registry logic.
    function trustedIssuersRegistryImplementation()
        external
        view
        returns (address trustedIssuersRegistryImplementationAddress);

    /// @notice Retrieves the current, active smart contract address of the standard identity contract's logic.
    /// @dev Standard identity contracts are the actual on-chain representations of individual users, organizations, or
    /// entities within the SMART Protocol. These contracts typically hold claims and attributes related to an identity.
    /// This function returns the address of the base implementation (template) contract that new standard identity
    /// contracts will be created from (often via a proxy pattern).
    /// This address can change if the underlying logic for standard identity contracts is upgraded.
    /// @return identityImplementationAddress The blockchain address of the smart contract containing the standard
    /// identity logic.
    function identityImplementation() external view returns (address identityImplementationAddress);

    /// @notice Retrieves the current, active smart contract address of the token identity contract's logic.
    /// @dev Token identity contracts are a specialized type of identity contract that might be specifically linked to
    /// certain tokens, tokenized assets, or have features tailored for token interactions.
    /// This function returns the address of the base implementation (template) contract that new token identity
    /// contracts will be created from.
    /// This address can change if the underlying logic for token identity contracts is upgraded.
    /// @return tokenIdentityImplementationAddress The blockchain address of the smart contract containing the token
    /// identity logic.
    function tokenIdentityImplementation() external view returns (address tokenIdentityImplementationAddress);

    /// @notice Retrieves the smart contract address of the proxy for the compliance module.
    /// @dev A proxy contract is an intermediary contract that delegates all function calls it receives to another
    /// contract, known as the implementation contract (which contains the actual logic).
    /// The primary benefit of using a proxy is that the underlying logic (implementation) can be upgraded
    /// without changing the address that other contracts or users interact with. This provides flexibility and
    /// allows for bug fixes or feature additions without disrupting the ecosystem.
    /// This function returns the stable, unchanging address of the compliance module's proxy contract.
    /// All interactions with the compliance module should go through this proxy address.
    /// @return complianceProxyAddress The blockchain address of the compliance module's proxy contract.
    function complianceProxy() external view returns (address complianceProxyAddress);

    /// @notice Retrieves the smart contract address of the proxy for the identity registry module.
    /// @dev Similar to the compliance proxy, this function returns the stable, unchanging address of the identity
    /// registry's proxy contract.
    /// To interact with the identity registry (e.g., to query identity information or register a new identity,
    /// depending on its features), you should use this proxy address. It will automatically forward your requests
    /// to the current logic implementation contract.
    /// @return identityRegistryProxyAddress The blockchain address of the identity registry module's proxy contract.
    function identityRegistryProxy() external view returns (address identityRegistryProxyAddress);

    /// @notice Retrieves the smart contract address of the proxy for the identity registry storage module.
    /// @dev This function returns the stable, unchanging address of the identity registry storage's proxy contract.
    /// All interactions related to storing or retrieving identity data should go through this proxy address.
    /// It ensures that calls are directed to the current logic implementation for identity data management.
    /// @return identityRegistryStorageProxyAddress The blockchain address of the identity registry storage module's
    /// proxy contract.
    function identityRegistryStorageProxy() external view returns (address identityRegistryStorageProxyAddress);

    /// @notice Retrieves the smart contract address of the proxy for the trusted issuers registry module.
    /// @dev This function returns the stable, unchanging address of the trusted issuers registry's proxy contract.
    /// To interact with the trusted issuers registry (e.g., to check if an issuer is trusted or to add/remove
    /// issuers, depending on its features), you should use this proxy address. It will forward calls to the
    /// current logic implementation.
    /// @return trustedIssuersRegistryProxyAddress The blockchain address of the trusted issuers registry module's
    /// proxy.
    function trustedIssuersRegistryProxy() external view returns (address trustedIssuersRegistryProxyAddress);

    /// @notice Retrieves the smart contract address of the proxy for the identity factory module.
    /// @dev This function returns the stable, unchanging address of the identity factory's proxy contract.
    /// To create new identities within the SMART Protocol, you should interact with this proxy address.
    /// It will delegate the identity creation requests to the current active logic implementation of the
    /// identity factory.
    /// @return identityFactoryProxyAddress The blockchain address of the identity factory module's proxy contract.
    function identityFactoryProxy() external view returns (address identityFactoryProxyAddress);
}
