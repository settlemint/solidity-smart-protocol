// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { AbstractSMARTTokenFactoryImplementation } from
    "../../system/token-factory/AbstractSMARTTokenFactoryImplementation.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { ISMARTBond } from "./ISMARTBond.sol";
import { ISMARTBondFactory } from "./ISMARTBondFactory.sol";
import { ISMARTTokenAccessManager } from "../../extensions/access-managed/ISMARTTokenAccessManager.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Local imports
import { SMARTBondProxy } from "./SMARTBondProxy.sol";

contract SMARTBondFactoryImplementation is ISMARTBondFactory, AbstractSMARTTokenFactoryImplementation {
    constructor(address forwarder) payable AbstractSMARTTokenFactoryImplementation(forwarder) { }

    function createBond(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 cap_,
        uint256 maturityDate_,
        uint256 faceValue_,
        address underlyingAsset_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        external
        override
        returns (address deployedBondAddress)
    {
        // Create the access manager for the token
        ISMARTTokenAccessManager accessManager = _createAccessManager(name_, symbol_);

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
            _identityRegistry(),
            _compliance(),
            address(accessManager)
        );

        // Get the creation bytecode of SMARTBondProxy
        bytes memory proxyBytecode = type(SMARTBondProxy).creationCode;

        // Deploy using the helper from the abstract contract
        deployedBondAddress = _deployToken(proxyBytecode, constructorArgs, name_, symbol_, address(accessManager));

        return deployedBondAddress;
    }

    function isValidTokenImplementation(address tokenImplementation_) public view returns (bool) {
        return IERC165(tokenImplementation_).supportsInterface(type(ISMARTBond).interfaceId);
    }

    /// @notice Predicts the deployment address of a SMARTBondProxy contract.
    /// @param name_ The name of the bond.
    /// @param symbol_ The symbol of the bond.
    /// @param decimals_ The decimals of the bond.
    /// @param cap_ The cap of the bond.
    /// @param maturityDate_ The maturity date of the bond.
    /// @param faceValue_ The face value of the bond.
    /// @param underlyingAsset_ The underlying asset of the bond.
    /// @param requiredClaimTopics_ The required claim topics for the bond.
    /// @param initialModulePairs_ The initial compliance module pairs for the bond.
    /// @return predictedAddress The predicted address of the bond contract.
    function predictBondAddress(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 cap_,
        uint256 maturityDate_,
        uint256 faceValue_,
        address underlyingAsset_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        public
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
            cap_,
            maturityDate_,
            faceValue_,
            underlyingAsset_,
            requiredClaimTopics_,
            initialModulePairs_,
            _identityRegistry(),
            _compliance(),
            accessManagerAddress_
        );

        bytes memory proxyBytecode = type(SMARTBondProxy).creationCode;
        predictedAddress = _predictProxyAddress(proxyBytecode, constructorArgs, name_, symbol_);
        return predictedAddress;
    }
}
