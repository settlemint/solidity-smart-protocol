// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// Openzeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Base contract imports
import { SMARTExtension } from "../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTCustodianLogic } from "./internal/_SMARTCustodianLogic.sol";

// Error imports
import { LengthMismatch } from "./../common/CommonErrors.sol";

/// @title Standard SMART Custodian Extension
/// @notice Standard (non-upgradeable) extension that adds custodian features (freezing, forced transfer, recovery) to a
/// SMART token.
/// @dev Inherits core custodian logic from `_SMARTCustodianLogic`, `SMARTExtension`,
///      and expects the final contract to inherit a standard `ERC20` implementation and core `SMART` logic.
///      Requires an accompanying authorization contract (e.g., `SMARTCustodianAccessControlAuthorization`).
abstract contract SMARTCustodian is SMARTExtension, _SMARTCustodianLogic {
    // Note: Assumes the final contract inherits ERC20 and SMART

    constructor() payable {
        __SMARTCustodian_init_unchained();
    }

    // -- Internal Hook Implementations (Dependencies) --

    /// @notice Implementation of the abstract balance getter using standard ERC20.balanceOf.
    /// @inheritdoc _SMARTCustodianLogic
    function __custodian_getBalance(address account) internal view virtual override returns (uint256) {
        return balanceOf(account); // Assumes ERC20.balanceOf is available
    }

    /// @notice Implementation of the abstract transfer executor using standard ERC20._update.
    /// @inheritdoc _SMARTCustodianLogic
    function __custodian_executeTransferUpdate(address from, address to, uint256 amount) internal virtual override {
        _update(from, to, amount); // Assumes ERC20._update is available and overridden by SMART to handle hooks
    }

    // -- Hooks (Overrides) --

    /// @inheritdoc SMARTHooks
    /// @dev Adds check to prevent minting to a frozen address.
    function _beforeMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        __custodian_beforeMintLogic(to, amount);
        super._beforeMint(to, amount); // Call next hook in the chain
    }

    /// @inheritdoc SMARTHooks
    /// @dev Adds checks for frozen sender/recipient and sufficient unfrozen balance.
    function _beforeTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        __custodian_beforeTransferLogic(from, to, amount);
        super._beforeTransfer(from, to, amount); // Call next hook in the chain
    }

    /// @inheritdoc SMARTHooks
    /// @dev Adds logic to automatically unfreeze tokens if a burn requires them (for admin burns).
    function _beforeBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        __custodian_beforeBurnLogic(from, amount);
        super._beforeBurn(from, amount); // Call next hook in the chain
    }

    /// @inheritdoc SMARTHooks
    /// @dev Adds checks for frozen sender and sufficient unfrozen balance (for user-initiated redeems).
    function _beforeRedeem(address from, uint256 amount) internal virtual override(SMARTHooks) {
        __custodian_beforeRedeemLogic(from, amount);
        super._beforeRedeem(from, amount); // Call next hook in the chain
    }
}
