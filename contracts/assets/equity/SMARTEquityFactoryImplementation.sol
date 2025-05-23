// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { AbstractSMARTTokenFactoryImplementation } from
    "../../system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { ISMARTEquity } from "./ISMARTEquity.sol";
import { ISMARTTokenAccessManager } from "../../extensions/access-managed/ISMARTTokenAccessManager.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";
import { ISMARTEquityFactory } from "./ISMARTEquityFactory.sol";
// Local imports
import { SMARTEquityProxy } from "./SMARTEquityProxy.sol";

/// @title Implementation of the SMART Equity Factory
/// @notice This contract is responsible for creating instances of SMART Equity tokens.
contract SMARTEquityFactoryImplementation is ISMARTEquityFactory, AbstractSMARTTokenFactoryImplementation {
    /// @notice Constructor for the SMARTEquityFactoryImplementation.
    /// @param forwarder The address of the trusted forwarder for meta-transactions.
    constructor(address forwarder) payable AbstractSMARTTokenFactoryImplementation(forwarder) { }

    /// @notice Creates a new SMART Equity token.
    /// @param name_ The name of the equity token.
    /// @param symbol_ The symbol of the equity token.
    /// @param decimals_ The number of decimals for the equity token.
    /// @param equityClass_ The class of the equity (e.g., Common, Preferred).
    /// @param equityCategory_ The category of the equity (e.g., Voting, Non-Voting).
    /// @param requiredClaimTopics_ An array of claim topics required for interacting with the equity token.
    /// @param initialModulePairs_ An array of initial compliance module and parameter pairs.
    /// @return deployedEquityAddress The address of the newly deployed equity token contract.
    function createEquity(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        string memory equityClass_,
        string memory equityCategory_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        override
        returns (address deployedEquityAddress)
    {
        // slither-disable-next-line encode-packed-collision
        bytes memory salt = abi.encodePacked(name_, symbol_, decimals_);
        // Create the access manager for the token
        ISMARTTokenAccessManager accessManager = _createAccessManager(salt);

        // ABI encode constructor arguments for SMARTDepositProxy
        bytes memory constructorArgs = abi.encode(
            address(this),
            name_,
            symbol_,
            decimals_,
            equityClass_,
            equityCategory_,
            requiredClaimTopics_,
            initialModulePairs_,
            _identityRegistry(),
            _compliance(),
            address(accessManager)
        );

        // Get the creation bytecode of SMARTDepositProxy
        bytes memory proxyBytecode = type(SMARTEquityProxy).creationCode;

        // Deploy using the helper from the abstract contract
        deployedEquityAddress = _deployToken(proxyBytecode, constructorArgs, salt, address(accessManager));

        return deployedEquityAddress;
    }

    /// @notice Checks if a given address implements the ISMARTEquity interface.
    /// @param tokenImplementation_ The address of the contract to check.
    /// @return bool True if the contract supports the ISMARTEquity interface, false otherwise.
    function isValidTokenImplementation(address tokenImplementation_) public view override returns (bool) {
        return IERC165(tokenImplementation_).supportsInterface(type(ISMARTEquity).interfaceId);
    }

    /// @notice Predicts the deployment address of a SMARTEquityProxy contract.
    /// @param name_ The name of the equity.
    /// @param symbol_ The symbol of the equity.
    /// @param decimals_ The decimals of the equity.
    /// @param equityClass_ The class of the equity.
    /// @param equityCategory_ The category of the equity.
    /// @param requiredClaimTopics_ The required claim topics for the equity.
    /// @param initialModulePairs_ The initial compliance module pairs for the equity.
    /// @return predictedAddress The predicted address of the equity contract.
    function predictEquityAddress(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        string memory equityClass_,
        string memory equityCategory_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        view
        override
        returns (address predictedAddress)
    {
        // slither-disable-next-line encode-packed-collision
        bytes memory salt = abi.encodePacked(name_, symbol_, decimals_);
        address accessManagerAddress_ = _predictAccessManagerAddress(salt);
        bytes memory constructorArgs = abi.encode(
            address(this),
            name_,
            symbol_,
            decimals_,
            equityClass_,
            equityCategory_,
            requiredClaimTopics_,
            initialModulePairs_,
            _identityRegistry(),
            _compliance(),
            accessManagerAddress_
        );

        bytes memory proxyBytecode = type(SMARTEquityProxy).creationCode;
        predictedAddress = _predictProxyAddress(proxyBytecode, constructorArgs, salt);
        return predictedAddress;
    }
}
