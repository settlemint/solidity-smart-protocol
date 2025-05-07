// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Interface imports
import { ISMART } from "../../interface/ISMART.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Base contract imports
import { SMARTExtension } from "../common/SMARTExtension.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTLogic } from "./internal/_SMARTLogic.sol";

// Error imports
import { LengthMismatch } from "../common/CommonErrors.sol";

/// @title Standard SMART Token Implementation
/// @notice Standard (non-upgradeable) implementation of the core SMART token functionality, including ERC20 compliance,
///         identity verification, and compliance checks.
/// @dev Inherits core logic from `_SMARTLogic`, authorization hooks from the chosen authorization contract (e.g.,
/// `SMARTAccessControlAuthorization`),
///      and standard OpenZeppelin `ERC20`.
///      Requires an accompanying authorization contract to be inherited for permissioned functions.
abstract contract SMART is SMARTExtension, _SMARTLogic {
    // --- Custom Errors ---
    // Errors are inherited from _SMARTLogic

    // --- Storage Variables ---
    // State variables are inherited from _SMARTLogic (prefixed with __)
    // Note: immutable _decimals removed, now stored in __decimals

    // --- Events ---
    // Events are inherited from _SMARTLogic

    // --- Constructor ---
    /// @notice Initializes the SMART token contract.
    /// @param name_ The name of the token.
    /// @param symbol_ The symbol of the token.
    /// @param decimals_ The number of decimals the token uses.
    /// @param onchainID_ Optional on-chain identifier address.
    /// @param identityRegistry_ Address of the identity registry contract.
    /// @param compliance_ Address of the compliance contract.
    /// @param requiredClaimTopics_ Initial list of required claim topics for verification.
    /// @param initialModulePairs_ List of initial compliance modules and their parameters.
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        ERC20(name_, symbol_) // Initialize ERC20 base
    {
        // Initialize the core SMART logic state using the internal function
        __SMART_init_unchained(
            name_,
            symbol_,
            decimals_,
            onchainID_,
            identityRegistry_,
            compliance_,
            requiredClaimTopics_,
            initialModulePairs_
        );
        // Note: Authorization contract (e.g., AccessControl) initialization
        // and role granting should happen in the final concrete contract's constructor.
    }

    // --- State-Changing Functions ---

    /// @inheritdoc ISMART
    /// @dev Mints new tokens to a specified address.
    ///      Requires authorization via `_authorizeMintToken` (typically MINTER_ROLE).
    ///      Includes compliance and verification checks via `_beforeMint` hook.
    function mint(address to, uint256 amount) external virtual override {
        _mint(to, amount); // Calls _update -> _beforeMint -> _smart_beforeMintLogic (auth check)
    }

    /// @inheritdoc ISMART
    /// @dev Mints tokens to multiple addresses in a single transaction.
    ///      Requires authorization via `_authorizeMintToken` for each mint.
    ///      Includes compliance and verification checks via `_beforeMint` hook for each mint.
    function batchMint(address[] calldata toList, uint256[] calldata amounts) external virtual override {
        if (toList.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < toList.length; i++) {
            _mint(toList[i], amounts[i]);
        }
    }

    /// @inheritdoc ERC20
    /// @dev Overrides ERC20.transfer to integrate SMART verification and compliance checks via hooks.
    function transfer(address to, uint256 amount) public virtual override(ERC20, IERC20) returns (bool) {
        address sender = _msgSender();
        _transfer(sender, to, amount); // Calls _update -> _beforeTransfer/_afterTransfer
        return true;
    }

    /// @inheritdoc ISMART
    /// @dev Performs multiple transfers from the caller in a single transaction.
    ///      Integrates SMART verification and compliance checks for each transfer via hooks.
    function batchTransfer(address[] calldata toList, uint256[] calldata amounts) external virtual override {
        if (toList.length != amounts.length) revert LengthMismatch();
        address sender = _msgSender(); // Cache sender
        for (uint256 i = 0; i < toList.length; i++) {
            _transfer(sender, toList[i], amounts[i]);
        }
    }

    // --- View Functions ---

    /// @inheritdoc ERC20
    function name() public view virtual override(ERC20, IERC20Metadata) returns (string memory) {
        return __name; // Return mutable name from _SMARTLogic state
    }

    /// @inheritdoc ERC20
    function symbol() public view virtual override(ERC20, IERC20Metadata) returns (string memory) {
        return __symbol; // Return mutable symbol from _SMARTLogic state
    }

    /// @inheritdoc ERC20
    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return __decimals; // Return decimals from _SMARTLogic state
    }

    /**
     * @dev Overrides ERC20._update to centralize calls to SMART-specific hooks based on the operation type.
     * Detects mints (from == address(0)), burns (to == address(0)), and transfers.
     * Calls the corresponding `_before<Action>` and `_after<Action>` hooks defined in `SMARTHooks`,
     * which in turn call the `_smart_<action>Logic` helpers in `_SMARTLogic`.
     * Skips hooks if `__isForcedUpdate` (from `SMARTExtension`) is true.
     * @param from The sender address (address(0) for mints).
     * @param to The recipient address (address(0) for burns).
     * @param value The amount being transferred/minted/burned.
     */
    function _update(address from, address to, uint256 value) internal virtual override(ERC20) {
        if (from == address(0)) {
            // Mint
            if (!__isForcedUpdate) {
                _beforeMint(to, value);
            }
            super._update(from, to, value); // Perform ERC20 update
            if (!__isForcedUpdate) {
                _afterMint(to, value);
            }
        } else if (to == address(0)) {
            // Burn
            if (!__isForcedUpdate) {
                _beforeBurn(from, value);
            }
            super._update(from, to, value); // Perform ERC20 update
            if (!__isForcedUpdate) {
                _afterBurn(from, value);
            }
        } else {
            // Transfer
            if (!__isForcedUpdate) {
                _beforeTransfer(from, to, value);
            }
            super._update(from, to, value); // Perform ERC20 update
            if (!__isForcedUpdate) {
                _afterTransfer(from, to, value);
            }
        }
    }

    // --- Hooks ---

    /// @inheritdoc SMARTHooks
    /// @dev Calls the core SMART minting logic check before proceeding.
    function _beforeMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _smart_beforeMintLogic(to, amount);
        super._beforeMint(to, amount); // Allow further extension hooks
    }

    /// @inheritdoc SMARTHooks
    /// @dev Calls the core SMART minting logic notification after completion.
    function _afterMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _smart_afterMintLogic(to, amount);
        super._afterMint(to, amount); // Allow further extension hooks
    }

    /// @inheritdoc SMARTHooks
    /// @dev Calls the core SMART transfer logic check before proceeding.
    function _beforeTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        _smart_beforeTransferLogic(from, to, amount);
        super._beforeTransfer(from, to, amount); // Allow further extension hooks
    }

    /// @inheritdoc SMARTHooks
    /// @dev Calls the core SMART transfer logic notification after completion.
    function _afterTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        _smart_afterTransferLogic(from, to, amount);
        super._afterTransfer(from, to, amount); // Allow further extension hooks
    }

    /// @inheritdoc SMARTHooks
    /// @dev Calls the core SMART burn logic notification after completion.
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _smart_afterBurnLogic(from, amount);
        super._afterBurn(from, amount); // Allow further extension hooks
    }
}
