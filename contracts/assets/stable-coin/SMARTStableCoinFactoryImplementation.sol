// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { AbstractSMARTTokenFactoryImplementation } from
    "../../system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { ISMARTStableCoin } from "./ISMARTStableCoin.sol";
import { ISMARTStableCoinFactory } from "./ISMARTStableCoinFactory.sol";
import { ISMARTTokenAccessManager } from "../../extensions/access-managed/ISMARTTokenAccessManager.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Local imports
import { SMARTStableCoinProxy } from "./SMARTStableCoinProxy.sol";

contract SMARTStableCoinFactoryImplementation is ISMARTStableCoinFactory, AbstractSMARTTokenFactoryImplementation {
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
        ISMARTTokenAccessManager accessManager = _createAccessManager(name_, symbol_);

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
        deployedStableCoinAddress = _deployToken(proxyBytecode, constructorArgs, name_, symbol_, address(accessManager));

        return deployedStableCoinAddress;
    }

    function isValidTokenImplementation(address tokenImplementation_) public view returns (bool) {
        return IERC165(tokenImplementation_).supportsInterface(type(ISMARTStableCoin).interfaceId);
    }

    /// @notice Predicts the deployment address of a SMARTStableCoinProxy contract.
    /// @param name_ The name of the stable coin.
    /// @param symbol_ The symbol of the stable coin.
    /// @param decimals_ The decimals of the stable coin.
    /// @param requiredClaimTopics_ The required claim topics for the stable coin.
    /// @param initialModulePairs_ The initial compliance module pairs for the stable coin.
    /// @return predictedAddress The predicted address of the stable coin contract.
    function predictStableCoinAddress(
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
        address accessManagerAddress_ = _predictAccessManagerAddress(name_, symbol_);
        bytes memory constructorArgs = abi.encode(
            address(this),
            name_,
            symbol_,
            decimals_,
            requiredClaimTopics_,
            initialModulePairs_,
            _identityRegistry(),
            _compliance(),
            accessManagerAddress_
        );

        bytes memory proxyBytecode = type(SMARTStableCoinProxy).creationCode;
        predictedAddress = _predictProxyAddress(proxyBytecode, constructorArgs, name_, symbol_);
        return predictedAddress;
    }
}
