// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";

import { SMARTBondImplementation } from "./SMARTBondImplementation.sol";

import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";
import { ISMARTTokenFactory } from "../../system/token-factory/ISMARTTokenFactory.sol";

import {
    InvalidTokenFactoryAddress,
    TokenImplementationNotSet,
    ETHTransfersNotAllowed,
    InitializationFailed
} from "../../system/SMARTSystemErrors.sol";

/// @title Proxy contract for SMART Bonds, retrieving implementation from Token Registry.
/// @notice This contract serves as a proxy, allowing for upgradeability of the underlying bond logic.
/// It retrieves the implementation address from the ISMARTTokenRegistry contract.
contract SMARTBondProxy is Proxy {
    // keccak256("org.smart.contracts.proxy.SMARTBondProxy.tokenFactory")
    bytes32 private constant _TOKEN_FACTORY_SLOT = 0x8154d1e41bb5a323fe0619b76db6fd0dfb7e53cd15405b6b1d93d4eafd078c22;

    function _setTokenFactory(ISMARTTokenFactory tokenFactory_) internal {
        StorageSlot.getAddressSlot(_TOKEN_FACTORY_SLOT).value = address(tokenFactory_);
    }

    function _getTokenFactory() internal view returns (ISMARTTokenFactory) {
        return ISMARTTokenFactory(StorageSlot.getAddressSlot(_TOKEN_FACTORY_SLOT).value);
    }

    /// @notice Constructs the SMARTBondProxy.
    /// @dev Initializes the proxy by setting the token factory address and delegating a call
    /// to the `initialize` function of the implementation provided by the token factory.
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
    {
        if (
            tokenFactoryAddress == address(0)
                || !IERC165(tokenFactoryAddress).supportsInterface(type(ISMARTTokenFactory).interfaceId)
        ) {
            revert InvalidTokenFactoryAddress();
        }
        _setTokenFactory(ISMARTTokenFactory(tokenFactoryAddress));

        ISMARTTokenFactory tokenFactory_ = _getTokenFactory();
        address implementation = tokenFactory_.tokenImplementation();
        if (implementation == address(0)) revert TokenImplementationNotSet();

        bytes memory data = abi.encodeWithSelector(
            SMARTBondImplementation.initialize.selector,
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

        // slither-disable-next-line low-level-calls
        (bool success,) = implementation.delegatecall(data);
        if (!success) revert InitializationFailed();
    }

    /// @notice Returns the address of the current implementation.
    /// @dev This function is called by the EIP1967Proxy logic to determine where to delegate calls.
    /// @return implementationAddress The address of the implementation contract provided by the token registry.
    function _implementation() internal view override returns (address) {
        ISMARTTokenFactory tokenFactory_ = _getTokenFactory();
        return tokenFactory_.tokenImplementation();
    }

    /// @notice Rejects Ether transfers.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
