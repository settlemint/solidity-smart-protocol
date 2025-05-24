// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { AbstractSMARTTokenFactoryImplementation } from
    "../../system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { ISMARTDeposit } from "./ISMARTDeposit.sol";
import { ISMARTTokenAccessManager } from "../../extensions/access-managed/ISMARTTokenAccessManager.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";
import { ISMARTDepositFactory } from "./ISMARTDepositFactory.sol";

// Local imports
import { SMARTDepositProxy } from "./SMARTDepositProxy.sol";

/// @title Implementation of the SMART Deposit Factory
/// @notice This contract is responsible for creating instances of SMART Deposit tokens.
contract SMARTDepositFactoryImplementation is ISMARTDepositFactory, AbstractSMARTTokenFactoryImplementation {
    /// @notice Constructor for the SMARTDepositFactoryImplementation.
    /// @param forwarder The address of the trusted forwarder for meta-transactions.
    constructor(address forwarder) payable AbstractSMARTTokenFactoryImplementation(forwarder) { }

    /// @notice Creates a new SMART Deposit token.
    /// @param name_ The name of the deposit token.
    /// @param symbol_ The symbol of the deposit token.
    /// @param decimals_ The number of decimals for the deposit token.
    /// @param requiredClaimTopics_ An array of claim topics required for interacting with the deposit token.
    /// @param initialModulePairs_ An array of initial compliance module and parameter pairs.
    /// @return deployedDepositAddress The address of the newly deployed deposit token contract.
    function createDeposit(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        override
        returns (address deployedDepositAddress)
    {
        bytes memory salt = _buildSaltInput(name_, symbol_, decimals_);

        // Create the access manager for the token
        ISMARTTokenAccessManager accessManager = _createAccessManager(salt);

        // ABI encode constructor arguments for SMARTDepositProxy
        bytes memory constructorArgs = abi.encode(
            address(this),
            name_,
            symbol_,
            decimals_,
            requiredClaimTopics_,
            initialModulePairs_,
            _identityRegistry(),
            _compliance(),
            address(accessManager)
        );

        // Get the creation bytecode of SMARTDepositProxy
        bytes memory proxyBytecode = type(SMARTDepositProxy).creationCode;

        // Deploy using the helper from the abstract contract
        deployedDepositAddress = _deployToken(proxyBytecode, constructorArgs, salt, address(accessManager));

        return deployedDepositAddress;
    }

    /// @notice Checks if a given address implements the ISMARTDeposit interface.
    /// @param tokenImplementation_ The address of the contract to check.
    /// @return bool True if the contract supports the ISMARTDeposit interface, false otherwise.
    function isValidTokenImplementation(address tokenImplementation_) public view override returns (bool) {
        return IERC165(tokenImplementation_).supportsInterface(type(ISMARTDeposit).interfaceId);
    }

    /// @notice Predicts the deployment address of a SMARTDepositProxy contract.
    /// @param name_ The name of the token.
    /// @param symbol_ The symbol of the token.
    /// @param decimals_ The decimals of the token.
    /// @param requiredClaimTopics_ The required claim topics for the token.
    /// @param initialModulePairs_ The initial compliance module pairs for the token.
    /// @return predictedAddress The predicted address of the token contract.
    function predictDepositAddress(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        view
        override
        returns (address predictedAddress)
    {
        bytes memory salt = _buildSaltInput(name_, symbol_, decimals_);
        address accessManagerAddress_ = _predictAccessManagerAddress(salt);
        // ABI encode constructor arguments for SMARTDepositProxy
        bytes memory constructorArgs = abi.encode(
            address(this), // The factory address is part of the constructor args
            name_,
            symbol_,
            decimals_,
            requiredClaimTopics_,
            initialModulePairs_,
            _identityRegistry(),
            _compliance(),
            accessManagerAddress_ // Use the provided access manager address
        );

        // Get the creation bytecode of SMARTDepositProxy
        bytes memory proxyBytecode = type(SMARTDepositProxy).creationCode;

        // Predict the address using the helper from the abstract contract
        predictedAddress = _predictProxyAddress(proxyBytecode, constructorArgs, salt);

        return predictedAddress;
    }
}
