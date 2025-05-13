// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTCustodianLogic } from "./internal/_SMARTCustodianLogic.sol";

// Error imports
import { LengthMismatch } from "./../common/CommonErrors.sol";

/// @title Upgradeable SMART Custodian Extension
/// @notice Upgradeable extension that adds custodian features (freezing, forced transfer, recovery) to a SMART token.
/// @dev Inherits core custodian logic from `_SMARTCustodianLogic`, `SMARTExtensionUpgradeable`, and `Initializable`.
///      Expects the final contract to inherit an upgradeable `ERC20Upgradeable` implementation and core
/// `SMARTUpgradeable` logic.
///      Requires an accompanying authorization contract (e.g., `SMARTCustodianAccessControlAuthorization`).
abstract contract SMARTCustodianUpgradeable is Initializable, SMARTExtensionUpgradeable, _SMARTCustodianLogic {
    // Note: Assumes the final contract inherits ERC20Upgradeable and SMARTUpgradeable

    // -- Initializer --
    /// @notice Initializes the custodian extension specific state (currently none).
    /// @dev Should be called within the main contract's `initialize` function.
    ///      Uses the `onlyInitializing` modifier.
    function __SMARTCustodian_init() internal onlyInitializing {
        __SMARTCustodian_init_unchained();
    }

    // -- Internal Hook Implementations (Dependencies) --

    /// @notice Implementation of the abstract balance getter using ERC20Upgradeable.balanceOf.
    /// @inheritdoc _SMARTCustodianLogic
    function __custodian_getBalance(address account) internal view virtual override returns (uint256) {
        return balanceOf(account); // Assumes ERC20Upgradeable.balanceOf is available
    }

    /// @notice Implementation of the abstract transfer executor using ERC20Upgradeable._update.
    /// @inheritdoc _SMARTCustodianLogic
    function __custodian_executeTransferUpdate(address from, address to, uint256 amount) internal virtual override {
        _update(from, to, amount); // Assumes ERC20Upgradeable._update is available and overridden by SMARTUpgradeable
    }

    // -- Hooks (Overrides) --

    /// @inheritdoc SMARTHooks
    /// @dev Adds check to prevent minting to a frozen address.
    function _beforeUpdate(
        address sender,
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTHooks)
    {
        __custodian_beforeUpdateLogic(sender, from, to, amount);
        super._beforeUpdate(sender, from, to, amount); // Call next hook in the chain
    }
}
