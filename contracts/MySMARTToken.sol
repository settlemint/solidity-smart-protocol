// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { SMART } from "./SMART/extensions/SMART.sol";
import { SMARTPausable } from "./SMART/extensions/SMARTPausable.sol";
import { SMARTBurnable } from "./SMART/extensions/SMARTBurnable.sol";
import { SMARTCustodian } from "./SMART/extensions/SMARTCustodian.sol";

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
        address[] memory initialModules_
    )
        SMART(name_, symbol_, decimals_, onchainID_, identityRegistry_, compliance_, requiredClaimTopics_, initialModules_)
    { }

    /// @notice Override _beforeTokenTransfer to include all extension checks
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMART, SMARTPausable, SMARTCustodian)
    {
        super._beforeTokenTransfer(from, to, amount);

        // Check if the token is paused
        require(!paused(), "Token is paused");

        // Check if the sender's address is frozen
        require(!isFrozen(from), "Sender address is frozen");

        // Check if the sender has enough unfrozen tokens
        uint256 frozenTokens = getFrozenTokens(from);
        require(balanceOf(from) - frozenTokens >= amount, "Insufficient unfrozen tokens");
    }

    /// @notice Override _afterTokenTransfer to include all extension hooks
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMART, SMARTPausable, SMARTCustodian)
    {
        super._afterTokenTransfer(from, to, amount);
    }
}
