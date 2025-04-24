// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// SMART interfaces
import { ISMARTIdentityRegistry } from "./ISMARTIdentityRegistry.sol";
import { ISMARTCompliance } from "./ISMARTCompliance.sol";
import { ISMARTComplianceModule } from "./ISMARTComplianceModule.sol";

/// @title ISMART
/// @notice Base interface for SMART tokens that integrates with IdentityRegistry and Compliance
interface ISMART is IERC20, IERC20Metadata {
    /// Custom Errors
    error RecipientNotVerified();

    /// Structs
    /// @notice A struct to pair a compliance module with its parameters
    struct ComplianceModuleParamPair {
        address module;
        bytes params;
    }

    /// Events
    event IdentityRegistryAdded(address indexed _identityRegistry);
    event ComplianceAdded(address indexed _compliance);
    event UpdatedTokenInformation(
        string indexed _newName, string indexed _newSymbol, uint8 _newDecimals, address indexed _newOnchainID
    );
    event ComplianceModuleAdded(address indexed _module, bytes _params);
    event ComplianceModuleRemoved(address indexed _module);
    event ModuleParametersUpdated(address indexed _module, bytes _params);

    /// Setters
    function setName(string calldata _name) external;
    function setSymbol(string calldata _symbol) external;
    function setOnchainID(address _onchainID) external;
    function setIdentityRegistry(address _identityRegistry) external;
    function setCompliance(address _compliance) external;

    /// @notice Sets or updates the configuration parameters for a specific compliance module.
    ///         MUST validate parameters via module's validateParameters function before storing.
    /// @param _module The address of the module to configure
    /// @param _params The encoded parameters for the module
    function setParametersForComplianceModule(address _module, bytes calldata _params) external;

    /// Core Functions
    function mint(address _to, uint256 _amount) external;
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external;
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external;

    /// Module Validation & Management
    /// @notice Validates if a module implements the required interface AND if the provided parameters are valid for it.
    ///         Reverts if the module address is invalid, does not support the interface, or if parameters are invalid.
    /// @param _module The address of the module to validate
    /// @param _params The parameters to validate against the module
    function isValidComplianceModule(address _module, bytes calldata _params) external view;

    /// @notice Validates multiple modules and their corresponding parameters.
    ///         Reverts if any module address is invalid, does not support the interface, or if parameters are invalid.
    /// @param _pairs An array of module-parameter pairs to validate
    function areValidComplianceModules(ComplianceModuleParamPair[] calldata _pairs) external view;

    /// @notice Adds a new compliance module with its initial parameters.
    ///         MUST validate the module and parameters via isValidModule before adding.
    /// @param _module The address of the module to add
    /// @param _params The initial encoded parameters for the module
    function addComplianceModule(address _module, bytes calldata _params) external;

    /// @notice Removes a compliance module
    /// @param _module The address of the module to remove
    function removeComplianceModule(address _module) external;

    /// Getters
    function onchainID() external view returns (address);
    function identityRegistry() external view returns (ISMARTIdentityRegistry);
    function compliance() external view returns (ISMARTCompliance);
    function requiredClaimTopics() external view returns (uint256[] memory);

    /// @notice Gets the list of all compliance modules and their parameters
    /// @return An array of module-parameter pairs
    function complianceModules() external view returns (ComplianceModuleParamPair[] memory);

    /// @notice Gets the configuration parameters for a specific compliance module
    /// @param _module The address of the module
    /// @return bytes The encoded parameters for the module
    function getParametersForComplianceModule(address _module) external view returns (bytes memory);
}
