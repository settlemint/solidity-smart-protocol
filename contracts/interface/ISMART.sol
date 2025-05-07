// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// SMART interfaces
import { ISMARTIdentityRegistry } from "./ISMARTIdentityRegistry.sol";
import { ISMARTCompliance } from "./ISMARTCompliance.sol";
import { ISMARTComplianceModule } from "./ISMARTComplianceModule.sol";

// Structs
import { SMARTComplianceModuleParamPair } from "./structs/SMARTComplianceModuleParamPair.sol";

/// @title ISMART Token Interface
/// @notice Defines the core interface for SMART tokens, combining standard ERC20/Metadata functionality
///         with identity verification, compliance checks, and modular compliance features.
interface ISMART is IERC20, IERC20Metadata {
    // --- Custom Errors ---
    /// @notice Reverted when a transfer or mint recipient does not meet the required verification status.
    error RecipientNotVerified();

    // --- Events ---
    /// @notice Emitted when the identity registry contract address is updated.
    event IdentityRegistryAdded(address indexed _identityRegistry);
    /// @notice Emitted when the main compliance contract address is updated.
    event ComplianceAdded(address indexed _compliance);
    /// @notice Emitted when core token information (name, symbol, decimals, onchainID) is updated.
    event UpdatedTokenInformation(
        string indexed _newName, string indexed _newSymbol, uint8 _newDecimals, address indexed _newOnchainID
    );
    /// @notice Emitted when a new compliance module is added to the token.
    event ComplianceModuleAdded(address indexed _module, bytes _params);
    /// @notice Emitted when a compliance module is removed from the token.
    event ComplianceModuleRemoved(address indexed _module);
    /// @notice Emitted when the parameters for an existing compliance module are updated.
    event ModuleParametersUpdated(address indexed _module, bytes _params);
    /// @notice Emitted when the list of required claim topics is updated.
    event RequiredClaimTopicsUpdated(uint256[] _requiredClaimTopics);
    /// @notice Emitted when a token is transferred.
    event TransferCompleted(address indexed from, address indexed to, uint256 amount);
    /// @notice Emitted when a token is minted.
    event MintCompleted(address indexed to, uint256 amount);

    // --- Configuration Setters (Admin/Authorized) ---

    /// @notice Updates the token name.
    /// @param _name The new token name.
    function setName(string calldata _name) external;

    /// @notice Updates the token symbol.
    /// @param _symbol The new token symbol.
    function setSymbol(string calldata _symbol) external;

    /// @notice Sets or updates the optional on-chain identifier address associated with the token.
    /// @param _onchainID The address of the on-chain ID contract.
    function setOnchainID(address _onchainID) external;

    /// @notice Sets or updates the identity registry contract used for verification.
    /// @param _identityRegistry The address of the new ISMARTIdentityRegistry contract.
    function setIdentityRegistry(address _identityRegistry) external;

    /// @notice Sets or updates the main compliance contract.
    /// @param _compliance The address of the new ISMARTCompliance contract.
    function setCompliance(address _compliance) external;

    /// @notice Sets or updates the configuration parameters for a specific compliance module.
    /// @dev Implementations MUST validate parameters via the module's `validateParameters` function before storing.
    /// @param _module The address of the compliance module to configure.
    /// @param _params The ABI-encoded parameters for the module.
    function setParametersForComplianceModule(address _module, bytes calldata _params) external;

    /// @notice Sets the required claim topics used for identity verification.
    /// @param _requiredClaimTopics An array of claim topic IDs (numeric identifiers).
    function setRequiredClaimTopics(uint256[] calldata _requiredClaimTopics) external;

    // --- Core Token Functions ---

    /// @notice Mints new tokens to a specified address.
    /// @dev Implementations typically restrict this to authorized minters and perform verification/compliance checks.
    /// @param _to The address to mint tokens to.
    /// @param _amount The amount of tokens to mint.
    function mint(address _to, uint256 _amount) external;

    /// @notice Mints tokens to multiple addresses in a batch.
    /// @dev Implementations typically restrict this to authorized minters and perform checks for each recipient.
    /// @param _toList An array of recipient addresses.
    /// @param _amounts An array of corresponding token amounts.
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external;

    /// @notice Transfers tokens from the caller to multiple addresses in a batch.
    /// @dev Implementations perform verification/compliance checks for each recipient.
    /// @param _toList An array of recipient addresses.
    /// @param _amounts An array of corresponding token amounts.
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external;

    // --- Compliance Module Management & Validation (Admin/Authorized) ---

    /// @notice Adds a new compliance module with its initial parameters.
    /// @dev Implementations MUST validate the module and parameters (e.g., using `isValidComplianceModule`) before
    /// adding.
    /// @param _module The address of the module to add.
    /// @param _params The initial ABI-encoded parameters for the module.
    function addComplianceModule(address _module, bytes calldata _params) external;

    /// @notice Removes an active compliance module.
    /// @param _module The address of the module to remove.
    function removeComplianceModule(address _module) external;

    // --- Getters ---

    /// @notice Gets the optional on-chain identifier address associated with the token.
    /// @return The address of the on-chain ID contract, or address(0) if not set.
    function onchainID() external view returns (address);

    /// @notice Gets the currently configured identity registry contract.
    /// @return The address of the active ISMARTIdentityRegistry contract.
    function identityRegistry() external view returns (ISMARTIdentityRegistry);

    /// @notice Gets the currently configured main compliance contract.
    /// @return The address of the active ISMARTCompliance contract.
    function compliance() external view returns (ISMARTCompliance);

    /// @notice Gets the list of currently required claim topics for verification.
    /// @return An array of numeric claim topic IDs.
    function requiredClaimTopics() external view returns (uint256[] memory);

    /// @notice Gets the list of all active compliance modules and their parameters.
    /// @return An array of `ComplianceModuleParamPair` structs.
    function complianceModules() external view returns (SMARTComplianceModuleParamPair[] memory);
}
