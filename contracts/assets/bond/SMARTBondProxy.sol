// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { SMARTAssetProxy } from "../SMARTAssetProxy.sol";
import { ISMARTBond } from "./ISMARTBond.sol";

import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";
import { ISMARTTokenFactory } from "../../system/token-factory/ISMARTTokenFactory.sol";

import { TokenImplementationNotSet } from "../../system/SMARTSystemErrors.sol";

/// @title Proxy contract for SMART Bonds, using SMARTAssetProxy.
/// @notice This contract serves as a proxy, allowing for upgradeability of the underlying bond logic.
/// It retrieves the implementation address from the ISMARTTokenFactory contract via SMARTAssetProxy.
contract SMARTBondProxy is SMARTAssetProxy {
    /// @notice Constructs the SMARTBondProxy.
    /// @dev Initializes the proxy by delegating a call to the `initialize` function
    /// of the implementation provided by the token factory.
    /// @param tokenFactoryAddress The address of the token factory contract.
    /// @param name_ The name of the bond.
    /// @param symbol_ The symbol of the bond.
    /// @param decimals_ The number of decimals of the bond.
    /// @param cap_ The cap of the bond.
    /// @param maturityDate_ The maturity date of the bond.
    /// @param faceValue_ The face value of the bond.
    /// @param underlyingAsset_ The underlying asset of the bond.
    /// @param requiredClaimTopics_ The required claim topics of the bond.
    /// @param initialModulePairs_ The initial module pairs of the bond.
    /// @param identityRegistry_ The identity registry of the bond.
    /// @param compliance_ The compliance of the bond.
    /// @param accessManager_ The access manager of the bond.
    constructor(
        address tokenFactoryAddress,
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
        payable
        SMARTAssetProxy(tokenFactoryAddress)
    {
        ISMARTTokenFactory tokenFactory_ = _getTokenFactory();
        address implementation = _getSpecificImplementationAddress(tokenFactory_);

        bytes memory data = abi.encodeWithSelector(
            ISMARTBond.initialize.selector,
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

        _performInitializationDelegatecall(implementation, data);
    }

    /// @notice Retrieves the specific implementation address for the bond proxy from the token factory.
    /// @dev Implements the abstract function from `SMARTAssetProxy`.
    /// Reverts with `TokenImplementationNotSet` if the token factory does not return a valid implementation.
    /// @param tokenFactory The `ISMARTTokenFactory` instance to query.
    /// @return implementationAddress The address of the bond's logic/implementation contract.
    function _getSpecificImplementationAddress(ISMARTTokenFactory tokenFactory)
        internal
        view
        override
        returns (address implementationAddress)
    {
        implementationAddress = tokenFactory.tokenImplementation();
        if (implementationAddress == address(0)) {
            revert TokenImplementationNotSet();
        }
        return implementationAddress;
    }
}
