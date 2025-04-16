// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ISMARTIdentityRegistry } from "./ISMARTIdentityRegistry.sol";
import { ISMARTCompliance } from "./ISMARTCompliance.sol";
import { ISMARTComplianceModule } from "./ISMARTComplianceModule.sol";

/// @title ISMART
/// @notice Base interface for SMART tokens that integrates with IdentityRegistry and Compliance
interface ISMART is IERC20, IERC20Metadata {
    /// Events
    event IdentityRegistryAdded(address indexed _identityRegistry);
    event ComplianceAdded(address indexed _compliance);
    event UpdatedTokenInformation(
        string indexed _newName, string indexed _newSymbol, uint8 _newDecimals, address indexed _newOnchainID
    );
    event ComplianceModuleAdded(address indexed _module);
    event ComplianceModuleRemoved(address indexed _module);

    /// Setters
    function setName(string calldata _name) external;
    function setSymbol(string calldata _symbol) external;
    function setOnchainID(address _onchainID) external;
    function setIdentityRegistry(address _identityRegistry) external;
    function setCompliance(address _compliance) external;

    /// Core Functions
    function mint(address _to, uint256 _amount) external;
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external;
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external;

    /// Module Validation
    /// @notice Validates if a module implements the required ISMARTComplianceModule interface
    /// @param _module The address of the module to validate
    /// @return bool Whether the module is valid
    function isValidModule(address _module) external view returns (bool);

    /// @notice Validates multiple modules at once
    /// @param _modules The addresses of the modules to validate
    /// @return bool Whether all modules are valid
    function areValidModules(address[] calldata _modules) external view returns (bool);

    /// @notice Adds a new compliance module
    /// @param _module The address of the module to add
    function addComplianceModule(address _module) external;

    /// @notice Removes a compliance module
    /// @param _module The address of the module to remove
    function removeComplianceModule(address _module) external;

    /// Getters
    function onchainID() external view returns (address);
    function identityRegistry() external view returns (ISMARTIdentityRegistry);
    function compliance() external view returns (ISMARTCompliance);
    function requiredClaimTopics() external view returns (uint256[] memory);
    function complianceModules() external view returns (address[] memory);
}
