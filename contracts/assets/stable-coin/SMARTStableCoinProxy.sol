// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { SMARTAssetProxy } from "../SMARTAssetProxy.sol";
import { ISMARTStableCoin } from "./ISMARTStableCoin.sol";

import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";
import { ISMARTTokenFactory } from "../../system/token-factory/ISMARTTokenFactory.sol";

import { TokenImplementationNotSet } from "../../system/SMARTSystemErrors.sol";

/// @title Proxy contract for SMART Stable Coins, using SMARTAssetProxy.
/// @notice This contract serves as a proxy, allowing for upgradeability of the underlying stable coin logic.
/// It retrieves the implementation address from the ISMARTTokenFactory contract via SMARTAssetProxy.
contract SMARTStableCoinProxy is SMARTAssetProxy {
    /// @notice Constructs the SMARTStableCoinProxy.
    /// @dev Initializes the proxy by delegating a call to the `initialize` function
    /// of the implementation provided by the token factory.
    /// @param tokenFactoryAddress The address of the token factory contract.
    /// @param name_ The name of the stable coin.
    /// @param symbol_ The symbol of the stable coin.
    /// @param decimals_ The number of decimals of the stable coin.
    /// @param collateralTopicId_ The topic ID of the collateral claim.
    /// @param requiredClaimTopics_ The required claim topics of the stable coin.
    /// @param initialModulePairs_ The initial module pairs of the stable coin.
    /// @param identityRegistry_ The identity registry of the stable coin.
    /// @param compliance_ The compliance of the stable coin.
    /// @param accessManager_ The access manager of the stable coin.
    constructor(
        address tokenFactoryAddress,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 collateralTopicId_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_,
        address identityRegistry_,
        address compliance_,
        address accessManager_
    )
        payable
        SMARTAssetProxy(tokenFactoryAddress)
    {
        address implementation = _implementation();

        bytes memory data = abi.encodeWithSelector(
            ISMARTStableCoin.initialize.selector,
            name_,
            symbol_,
            decimals_,
            collateralTopicId_,
            requiredClaimTopics_,
            initialModulePairs_,
            identityRegistry_,
            compliance_,
            accessManager_
        );

        _performInitializationDelegatecall(implementation, data);
    }
}
