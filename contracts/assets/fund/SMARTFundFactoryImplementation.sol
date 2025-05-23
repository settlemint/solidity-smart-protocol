// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { AbstractSMARTTokenFactoryImplementation } from
    "../../system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { ISMARTFund } from "./ISMARTFund.sol";
import { ISMARTFundFactory } from "./ISMARTFundFactory.sol";
import { ISMARTTokenAccessManager } from "../../extensions/access-managed/ISMARTTokenAccessManager.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Local imports
import { SMARTFundProxy } from "./SMARTFundProxy.sol";

/// @title Implementation of the SMART Fund Factory
/// @notice This contract is responsible for creating instances of SMART Funds.
contract SMARTFundFactoryImplementation is ISMARTFundFactory, AbstractSMARTTokenFactoryImplementation {
    /// @notice Constructor for the SMARTFundFactoryImplementation.
    /// @param forwarder The address of the trusted forwarder for meta-transactions.
    constructor(address forwarder) payable AbstractSMARTTokenFactoryImplementation(forwarder) { }

    /// @notice Creates a new SMART Fund.
    /// @param name_ The name of the fund.
    /// @param symbol_ The symbol of the fund.
    /// @param decimals_ The number of decimals for the fund tokens.
    /// @param managementFeeBps_ The management fee in basis points.
    /// @param fundClass_ The class of the fund (e.g., Equity, Fixed Income).
    /// @param fundCategory_ The category of the fund (e.g., Growth, Value).
    /// @param requiredClaimTopics_ An array of claim topics required for interacting with the fund.
    /// @param initialModulePairs_ An array of initial compliance module and parameter pairs.
    /// @return deployedFundAddress The address of the newly deployed fund contract.
    function createFund(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint16 managementFeeBps_,
        string memory fundClass_,
        string memory fundCategory_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        override
        returns (address deployedFundAddress)
    {
        bytes memory salt = abi.encodePacked(name_, symbol_, decimals_);
        // Create the access manager for the token
        ISMARTTokenAccessManager accessManager = _createAccessManager(salt);

        // ABI encode constructor arguments for SMARTDepositProxy
        bytes memory constructorArgs = abi.encode(
            address(this),
            name_,
            symbol_,
            decimals_,
            managementFeeBps_,
            fundClass_,
            fundCategory_,
            requiredClaimTopics_,
            initialModulePairs_,
            _identityRegistry(),
            _compliance(),
            address(accessManager)
        );

        // Get the creation bytecode of SMARTDepositProxy
        bytes memory proxyBytecode = type(SMARTFundProxy).creationCode;

        // Deploy using the helper from the abstract contract
        deployedFundAddress = _deployToken(proxyBytecode, constructorArgs, salt, address(accessManager));

        return deployedFundAddress;
    }

    /// @notice Checks if a given address implements the ISMARTFund interface.
    /// @param tokenImplementation_ The address of the contract to check.
    /// @return bool True if the contract supports the ISMARTFund interface, false otherwise.
    function isValidTokenImplementation(address tokenImplementation_) public view override returns (bool) {
        return IERC165(tokenImplementation_).supportsInterface(type(ISMARTFund).interfaceId);
    }

    /// @notice Predicts the deployment address of a SMARTFundProxy contract.
    /// @param name_ The name of the fund.
    /// @param symbol_ The symbol of the fund.
    /// @param decimals_ The decimals of the fund.
    /// @param managementFeeBps_ The management fee in basis points for the fund.
    /// @param fundClass_ The class of the fund.
    /// @param fundCategory_ The category of the fund.
    /// @param requiredClaimTopics_ The required claim topics for the fund.
    /// @param initialModulePairs_ The initial compliance module pairs for the fund.
    /// @return predictedAddress The predicted address of the fund contract.
    function predictFundAddress(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint16 managementFeeBps_,
        string memory fundClass_,
        string memory fundCategory_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        view
        override
        returns (address predictedAddress)
    {
        bytes memory salt = abi.encodePacked(name_, symbol_, decimals_);
        address accessManagerAddress_ = _predictAccessManagerAddress(salt);
        bytes memory constructorArgs = abi.encode(
            address(this),
            name_,
            symbol_,
            decimals_,
            managementFeeBps_,
            fundClass_,
            fundCategory_,
            requiredClaimTopics_,
            initialModulePairs_,
            _identityRegistry(),
            _compliance(),
            accessManagerAddress_
        );

        bytes memory proxyBytecode = type(SMARTFundProxy).creationCode;
        predictedAddress = _predictProxyAddress(proxyBytecode, constructorArgs, salt);
        return predictedAddress;
    }
}
