// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { SMART } from "./SMART/extensions/SMART.sol";
import { SMARTPausable } from "./SMART/extensions/SMARTPausable.sol";
import { SMARTBurnable } from "./SMART/extensions/SMARTBurnable.sol";
import { SMARTCustodian } from "./SMART/extensions/SMARTCustodian.sol";
import { ISMARTIdentityRegistry } from "./SMART/interface/ISMARTIdentityRegistry.sol";
import { ISMART } from "./SMART/interface/ISMART.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SMARTHooks } from "./SMART/extensions/SMARTHooks.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MySMARTToken
/// @notice A complete implementation of a SMART token with all available extensions
contract MySMARTToken is SMART, SMARTCustodian, SMARTPausable, SMARTBurnable {
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
            initialModulePairs_
        )
        Ownable(initialOwner_)
    { }

    // --- Overrides for Conflicting Functions ---

    /// @inheritdoc ERC20
    function decimals() public view virtual override(SMART, ERC20, IERC20Metadata) returns (uint8) {
        return super.decimals(); // Use SMART implementation
    }

    /// @inheritdoc ERC20
    function transfer(address to, uint256 amount) public virtual override(SMART, ERC20, IERC20) returns (bool) {
        // Explicitly call SMART implementation which handles hooks
        return SMART.transfer(to, amount);
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
        // Explicitly call SMART implementation which handles hooks and allowance
        return SMART.transferFrom(from, to, amount);
    }

    /**
     * @dev Overrides required due to diamond inheritance involving ERC20Pausable and SMARTHooks/ERC20.
     * We explicitly call the Pausable implementation which includes the `whenNotPaused` check.
     */
    function _update(address from, address to, uint256 value) internal virtual override(SMARTPausable, ERC20) {
        // Call the Pausable implementation, which should correctly call super._update
        // which eventually reaches the SMARTHooks implementation used by SMART.
        SMARTPausable._update(from, to, value);
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
        override(SMARTBurnable, SMARTCustodian, SMARTHooks)
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
    function _afterBurn(address from, uint256 amount) internal virtual override(SMART, SMARTHooks) {
        super._afterBurn(from, amount);
    }
}
