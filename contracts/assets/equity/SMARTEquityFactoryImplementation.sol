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

contract SMARTEquityFactoryImplementation is ISMARTEquityFactory, AbstractSMARTTokenFactoryImplementation {
    constructor(address forwarder) payable AbstractSMARTTokenFactoryImplementation(forwarder) { }

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
        // Create the access manager for the token
        ISMARTTokenAccessManager accessManager = _createAccessManager(name_, symbol_);

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
        deployedEquityAddress = _deployToken(proxyBytecode, constructorArgs, name_, symbol_, address(accessManager));

        return deployedEquityAddress;
    }

    function isValidTokenImplementation(address tokenImplementation_) public view returns (bool) {
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
        address accessManagerAddress_ = _predictAccessManagerAddress(name_, symbol_);
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
        predictedAddress = _predictProxyAddress(proxyBytecode, constructorArgs, name_, symbol_);
        return predictedAddress;
    }
}
