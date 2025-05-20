// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { AbstractSMARTTokenFactoryImplementation } from
    "../../system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { ISMARTFund } from "./ISMARTFund.sol";
import { ISMARTTokenAccessManager } from "../../extensions/access-managed/ISMARTTokenAccessManager.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Local imports
import { SMARTFundProxy } from "./SMARTFundProxy.sol";

contract SMARTFundFactoryImplementation is AbstractSMARTTokenFactoryImplementation {
    constructor(address forwarder) payable AbstractSMARTTokenFactoryImplementation(forwarder) { }

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
        returns (address deployedFundAddress)
    {
        // Create the access manager for the token
        ISMARTTokenAccessManager accessManager = _createAccessManager();

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
        deployedFundAddress = _deployToken(proxyBytecode, constructorArgs, address(accessManager), name_, symbol_);

        return deployedFundAddress;
    }

    function isValidTokenImplementation(address tokenImplementation_) public view returns (bool) {
        return IERC165(tokenImplementation_).supportsInterface(type(ISMARTFund).interfaceId);
    }
}
