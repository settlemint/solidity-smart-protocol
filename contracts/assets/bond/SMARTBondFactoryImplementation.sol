// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { AbstractSMARTTokenFactoryImplementation } from
    "../../system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { ISMARTBond } from "./ISMARTBond.sol";
import { ISMARTTokenAccessManager } from "../../extensions/access-managed/ISMARTTokenAccessManager.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Local imports
import { SMARTBondProxy } from "./SMARTBondProxy.sol";

contract SMARTBondFactoryImplementation is AbstractSMARTTokenFactoryImplementation {
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
        // Create the access manager for the token
        ISMARTTokenAccessManager accessManager = _createAccessManager();

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
            address(accessManager)
        );

        // Get the creation bytecode of SMARTBondProxy
        bytes memory proxyBytecode = type(SMARTBondProxy).creationCode;

        // Deploy using the helper from the abstract contract
        return _deployToken(proxyBytecode, constructorArgs, address(accessManager), name_, symbol_);
    }

    function isValidTokenImplementation(address tokenImplementation_) public view returns (bool) {
        return IERC165(tokenImplementation_).supportsInterface(type(ISMARTBond).interfaceId);
    }
}
