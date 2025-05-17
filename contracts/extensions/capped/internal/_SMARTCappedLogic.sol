// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { _SMARTExtension } from "./../../common/_SMARTExtension.sol";
import { ISMARTCapped } from "./../ISMARTCapped.sol";
import { SMARTInvalidCap, SMARTExceededCap } from "./../SMARTCappedErrors.sol";

/// @title Internal Logic for SMART Capped Extension
/// @notice Provides the core storage and logic for capping the total supply of a SMART token.
/// @dev This contract is designed to be inherited by specific SMART Capped implementations (standard or upgradeable).
///      It expects the final contract to also inherit an ERC20 implementation to provide `totalSupply()`.
abstract contract _SMARTCappedLogic is _SMARTExtension, ISMARTCapped {
    // Direct storage for the cap value
    uint256 private _cap;

    /// @notice Abstract function to get the total supply of tokens.
    /// @dev This must be implemented by the inheriting contract (e.g., by inheriting ERC20).
    /// @return The current total supply of tokens.
    function __capped_totalSupply() internal view virtual returns (uint256);

    /// @dev Initializes the capped supply logic. Should only be called once.
    /// @param cap_ The maximum total supply for the token. Must be greater than 0.
    function __SMARTCapped_init_unchained(uint256 cap_) internal {
        if (cap_ == 0) {
            revert SMARTInvalidCap(cap_);
        }
        _cap = cap_;
    }

    /// @notice Returns the cap on the token's total supply.
    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    /// @dev Core logic to check if minting an amount would exceed the cap.
    ///      Called before the actual mint operation.
    /// @param amountToMint_ The amount of tokens intended to be minted.
    function __capped_beforeMintLogic(uint256 amountToMint_) internal view {
        uint256 currentTotalSupply = __capped_totalSupply();
        uint256 newTotalSupply = currentTotalSupply + amountToMint_; // Solidity ^0.8.0 checks for arithmetic overflow

        if (newTotalSupply > cap()) {
            revert SMARTExceededCap(newTotalSupply, cap());
        }
    }
}
