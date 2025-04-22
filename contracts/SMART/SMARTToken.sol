// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { SMART } from "./extensions/SMART.sol";
import { SMARTPausable } from "./extensions/SMARTPausable.sol";
import { SMARTBurnable } from "./extensions/SMARTBurnable.sol";
import { SMARTCustodian } from "./extensions/SMARTCustodian.sol";
import { ISMARTIdentityRegistry } from "./interface/ISMARTIdentityRegistry.sol";
import { ISMART } from "./interface/ISMART.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SMARTHooks } from "./extensions/common/SMARTHooks.sol";
import { SMARTRedeemable } from "./extensions/SMARTRedeemable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SMARTExtension } from "./extensions/SMARTExtension.sol";
/// @title SMARTToken
/// @notice A complete implementation of a SMART token with all available extensions

contract SMARTToken is SMART, SMARTCustodian, SMARTPausable, SMARTBurnable, SMARTRedeemable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        ISMART.ComplianceModuleParamPair[] memory initialModulePairs_,
        address initialOwner_
    )
        SMART(
            name_,
            symbol_,
            decimals_,
            onchainID_,
            identityRegistry_,
            compliance_,
            requiredClaimTopics_,
            initialModulePairs_,
            initialOwner_
        )
    { }

    // --- State-Changing Functions (Overrides) ---
    function transfer(address to, uint256 amount) public virtual override(SMART, ERC20, IERC20) returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        virtual
        override(SMART, ERC20, IERC20)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    // --- View Functions (Overrides) ---
    function name() public view virtual override(SMART, ERC20, IERC20Metadata) returns (string memory) {
        return super.name();
    }

    function symbol() public view virtual override(SMART, ERC20, IERC20Metadata) returns (string memory) {
        return super.symbol();
    }

    function decimals() public view virtual override(SMART, ERC20, IERC20Metadata) returns (uint8) {
        return super.decimals();
    }

    // --- Hooks ---

    function _validateMint(
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMART, SMARTPausable, SMARTCustodian, SMARTHooks)
    {
        super._validateMint(to, amount);
    }

    function _validateTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMART, SMARTPausable, SMARTCustodian, SMARTHooks)
    {
        super._validateTransfer(from, to, amount);
    }

    function _validateBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(SMARTBurnable, SMARTPausable, SMARTCustodian, SMARTHooks)
    {
        super._validateBurn(from, amount);
    }

    function _validateRedeem(
        address owner,
        uint256 amount
    )
        internal
        virtual
        override(SMARTRedeemable, SMARTCustodian, SMARTHooks)
    {
        super._validateRedeem(owner, amount);
    }

    function _afterMint(address to, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterMint(to, amount);
    }

    function _afterTransfer(address from, address to, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterTransfer(from, to, amount);
    }

    function _afterBurn(address from, uint256 amount) internal virtual override(SMART, SMARTBurnable, SMARTHooks) {
        super._afterBurn(from, amount);
    }

    function _afterRedeem(address owner, uint256 amount) internal virtual override(SMARTRedeemable, SMARTHooks) {
        super._afterRedeem(owner, amount);
    }

    // --- Internal Functions (Overrides) ---
    /**
     * @dev Explicitly call the Pausable implementation which includes the `whenNotPaused` check.
     */
    function _update(address from, address to, uint256 value) internal virtual override(SMARTPausable, ERC20) {
        super._update(from, to, value);
    }

    function _msgSender() internal view virtual override(SMARTRedeemable, Context) returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view virtual override(SMARTRedeemable, Context) returns (bytes calldata) {
        return super._msgData();
    }
}
