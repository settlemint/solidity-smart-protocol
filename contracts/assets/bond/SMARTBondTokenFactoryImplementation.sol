// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { AbstractSMARTTokenFactoryImplementation } from
    "../../system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";

// Interface imports
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Local imports
import { SMARTBondProxy } from "./SMARTBondProxy.sol";
import { SMARTTokenAccessManager } from "../../extensions/access-managed/manager/SMARTTokenAccessManager.sol";

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
        address compliance_
    )
        external
        returns (address deployedBondAddress)
    {
        // TODO: make accessManager also upgradeable
        SMARTTokenAccessManager accessManager = new SMARTTokenAccessManager(address(trustedForwarder()), _msgSender());

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
            accessManager
        );

        // Get the creation bytecode of SMARTBondProxy
        bytes memory proxyBytecode = type(SMARTBondProxy).creationCode;

        // Deploy using the helper from the abstract contract
        return _deployProxy(proxyBytecode, constructorArgs, address(accessManager), name_, symbol_);
    }
}
