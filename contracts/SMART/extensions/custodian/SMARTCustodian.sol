// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Interface imports
import { ISMART } from "../../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../../interface/ISMARTIdentityRegistry.sol";
import { IIdentity } from "../../../onchainid/interface/IIdentity.sol";

// Base contract imports
import { SMARTExtension } from "../common/SMARTExtension.sol";
import { SMARTHooks } from "./../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTCustodianLogic } from "./internal/_SMARTCustodianLogic.sol";

// Error imports
import { LengthMismatch } from "./../common/CommonErrors.sol";

/// @title SMARTCustodian
/// @notice Standard (non-upgradeable) extension that adds custodian features.
/// @dev Inherits from SMARTExtension, Ownable, and _SMARTCustodianLogic.
abstract contract SMARTCustodian is SMARTExtension, _SMARTCustodianLogic {
    // --- State-Changing Functions ---

    function setAddressFrozen(address userAddress, bool freeze) public virtual {
        _setAddressFrozen(userAddress, freeze); // Calls base logic
    }

    function freezePartialTokens(address userAddress, uint256 amount) public virtual {
        _freezePartialTokens(userAddress, amount); // Calls base logic
    }

    function unfreezePartialTokens(address userAddress, uint256 amount) public virtual {
        _unfreezePartialTokens(userAddress, amount); // Calls base logic
    }

    function batchSetAddressFrozen(address[] calldata userAddresses, bool[] calldata freeze) public virtual {
        if (userAddresses.length != freeze.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _setAddressFrozen(userAddresses[i], freeze[i]); // Calls base logic
        }
    }

    function batchFreezePartialTokens(address[] calldata userAddresses, uint256[] calldata amounts) public virtual {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _freezePartialTokens(userAddresses[i], amounts[i]); // Calls base logic
        }
    }

    function batchUnfreezePartialTokens(address[] calldata userAddresses, uint256[] calldata amounts) public virtual {
        if (userAddresses.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < userAddresses.length; i++) {
            _unfreezePartialTokens(userAddresses[i], amounts[i]); // Calls base logic
        }
    }

    /// @dev Requires owner privileges.
    function forcedTransfer(address from, address to, uint256 amount) public virtual returns (bool) {
        _beforeTransfer(from, to, amount, true); // Ensure custodian/other checks run first via hook chain
        _forcedTransfer(from, to, amount); // Call internal logic from base
        _afterTransfer(from, to, amount); // Call hook chain
        return true;
    }

    /// @dev Requires owner privileges.
    function batchForcedTransfer(
        address[] calldata fromList,
        address[] calldata toList,
        uint256[] calldata amounts
    )
        public
        virtual
    {
        if (!((fromList.length == toList.length) && (toList.length == amounts.length))) {
            revert LengthMismatch();
        }
        for (uint256 i = 0; i < fromList.length; i++) {
            forcedTransfer(fromList[i], toList[i], amounts[i]); // Calls single forcedTransfer
        }
    }

    /// @dev Requires owner privileges.
    function recoveryAddress(
        address lostWallet,
        address newWallet,
        address investorOnchainID
    )
        public
        virtual
        returns (bool)
    {
        _recoveryAddress(lostWallet, newWallet, investorOnchainID); // Calls base logic
        return true;
    }

    // --- Hooks ---

    /// @dev Returns the token balance of an address using ERC20.balanceOf.
    function _getBalance(address account) internal view virtual override(_SMARTCustodianLogic) returns (uint256) {
        return balanceOf(account); // Use ERC20.balanceOf
    }

    /// @dev Returns the identity registry instance (must be provided by the inheriting SMART contract).
    function _getIdentityRegistry()
        internal
        view
        virtual
        override(_SMARTCustodianLogic)
        returns (ISMARTIdentityRegistry)
    {
        // Relies on the concrete SMART contract implementing identityRegistry()
        return this.identityRegistry();
    }

    /// @dev Returns the required claim topics (must be provided by the inheriting SMART contract).
    function _getRequiredClaimTopics()
        internal
        view
        virtual
        override(_SMARTCustodianLogic)
        returns (uint256[] memory)
    {
        // Relies on the concrete SMART contract implementing requiredClaimTopics()
        return this.requiredClaimTopics();
    }

    /// @dev Executes the underlying token transfer using ERC20._update.
    function _executeTransferUpdate(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(_SMARTCustodianLogic)
    {
        // Call the internal _update function inherited from ERC20
        _update(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_beforeMintLogic(to, amount); // Call helper from base logic
        super._beforeMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeTransfer(
        address from,
        address to,
        uint256 amount,
        bool forced
    )
        internal
        virtual
        override(SMARTHooks)
    {
        _custodian_beforeTransferLogic(from, to, amount, forced); // Call helper from base logic
        super._beforeTransfer(from, to, amount, forced);
    }

    /// @inheritdoc SMARTHooks
    function _beforeBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_beforeBurnLogic(from, amount); // Call helper from base logic
        super._beforeBurn(from, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeRedeem(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _custodian_beforeRedeemLogic(from, amount); // Call helper from base logic
        super._beforeRedeem(from, amount);
    }
}
