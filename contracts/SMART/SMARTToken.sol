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
/// @title SMARTToken
/// @notice A complete implementation of a SMART token with all available extensions

contract SMARTToken is SMART, SMARTCustodian, SMARTPausable, SMARTBurnable {
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

    // --- Overrides for Conflicting Functions ---

    /// @inheritdoc ERC20
    function name() public view virtual override(SMART, ERC20, IERC20Metadata) returns (string memory) {
        return super.name();
    }

    /// @inheritdoc ERC20
    function symbol() public view virtual override(SMART, ERC20, IERC20Metadata) returns (string memory) {
        return super.symbol();
    }

    /// @inheritdoc ERC20
    function decimals() public view virtual override(SMART, ERC20, IERC20Metadata) returns (uint8) {
        return super.decimals();
    }

    /// @inheritdoc ERC20
    function transfer(address to, uint256 amount) public virtual override(SMART, ERC20, IERC20) returns (bool) {
        return super.transfer(to, amount);
    }

    /// @inheritdoc ERC20
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

    /**
     * @dev Overrides required due to diamond inheritance involving ERC20Pausable and SMARTExtension/ERC20.
     * We explicitly call the Pausable implementation which includes the `whenNotPaused` check.
     */
    function _update(address from, address to, uint256 value) internal virtual override(SMARTPausable, ERC20) {
        super._update(from, to, value);
    }

    // --- Overrides for Hook Functions ---
    // These overrides ensure that hooks from all relevant extensions are called in a defined order.

    /// @inheritdoc SMARTHooks
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

    /// @inheritdoc SMARTHooks
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

    /// @inheritdoc SMARTHooks
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

    /// @inheritdoc SMARTHooks
    function _afterMint(address to, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterTransfer(address from, address to, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterBurn(address from, uint256 amount) internal virtual override(SMART, SMARTBurnable, SMARTHooks) {
        super._afterBurn(from, amount);
    }
}
