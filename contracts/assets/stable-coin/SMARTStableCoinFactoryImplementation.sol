// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { AbstractSMARTTokenFactoryImplementation } from
    "../../system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { ISMARTStableCoin } from "./ISMARTStableCoin.sol";
import { ISMARTTokenAccessManager } from "../../extensions/access-managed/ISMARTTokenAccessManager.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Local imports
import { SMARTStableCoinProxy } from "./SMARTStableCoinProxy.sol";

contract SMARTStableCoinFactoryImplementation is AbstractSMARTTokenFactoryImplementation {
    constructor(address forwarder) payable AbstractSMARTTokenFactoryImplementation(forwarder) { }

    function createStableCoin(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        returns (address deployedStableCoinAddress)
    {
        // Create the access manager for the token
        ISMARTTokenAccessManager accessManager = _createAccessManager();

        // ABI encode constructor arguments for SMARTStableCoinProxy
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

        // Get the creation bytecode of SMARTStableCoinProxy
        bytes memory proxyBytecode = type(SMARTStableCoinProxy).creationCode;

        // Deploy using the helper from the abstract contract
        deployedStableCoinAddress = _deployToken(proxyBytecode, constructorArgs, address(accessManager), name_, symbol_);

        return deployedStableCoinAddress;
    }

    function isValidTokenImplementation(address tokenImplementation_) public view returns (bool) {
        return IERC165(tokenImplementation_).supportsInterface(type(ISMARTStableCoin).interfaceId);
    }
}
