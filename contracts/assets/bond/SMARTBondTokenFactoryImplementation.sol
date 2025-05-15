// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { AbstractSMARTTokenFactoryImplementation } from
    "../../system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";

// Interface imports
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Local imports
import { SMARTBondProxy } from "./SMARTBondProxy.sol";

contract SMARTBondTokenFactoryImplementation is AbstractSMARTTokenFactoryImplementation {
    constructor(address forwarder) AbstractSMARTTokenFactoryImplementation(forwarder) { }

    function createBond(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 cap_,
        uint256 maturityDate_,
        uint256 faceValue_,
        address underlyingAsset_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_,
        address identityRegistry_,
        address compliance_,
        address accessManager_
    )
        external
        returns (address deployedBondAddress)
    {
        // ABI encode constructor arguments for SMARTBondProxy
        bytes memory constructorArgs = abi.encode(
            address(this),
            name_,
            symbol_,
            decimals_,
            cap_,
            maturityDate_,
            faceValue_,
            underlyingAsset_,
            requiredClaimTopics_,
            initialModulePairs_,
            identityRegistry_,
            compliance_,
            accessManager_
        );

        // Get the creation bytecode of SMARTBondProxy
        bytes memory proxyBytecode = type(SMARTBondProxy).creationCode;

        // Deploy using the helper from the abstract contract
        deployedBondAddress = _deployProxyCREATE2(proxyBytecode, constructorArgs, name_, symbol_, "SMARTBondProxy");
    }
}
