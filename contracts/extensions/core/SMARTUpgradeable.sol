// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Interface imports
import { ISMART } from "../../interface/ISMART.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";
// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTLogic } from "./internal/_SMARTLogic.sol";

// Error imports
import { LengthMismatch } from "../common/CommonErrors.sol";

/// @title Upgradeable SMART Token Implementation (UUPS)
/// @notice Upgradeable implementation of the core SMART token functionality using the UUPS proxy pattern.
///         Includes ERC20 compliance, identity verification, and compliance checks.
/// @dev Inherits core logic from `_SMARTLogic`, authorization hooks from the chosen authorization contract,
///      and upgradeable OpenZeppelin contracts (`ERC20Upgradeable`, `UUPSUpgradeable`).
///      Requires an accompanying authorization contract (e.g., `SMARTAccessControlAuthorization`) and an
/// ownership/access control
///      contract (e.g., `OwnableUpgradeable` or `AccessControlUpgradeable`) to be inherited by the final contract for
/// initialization and upgrades.
abstract contract SMARTUpgradeable is Initializable, SMARTExtensionUpgradeable, UUPSUpgradeable, _SMARTLogic {
    // -- Initializer --
    /// @notice Internal initializer for the core SMART upgradeable state.
    /// @dev Calls the internal `__SMART_init_unchained` function from `_SMARTLogic` to set up core state.
    ///      Uses `onlyInitializing` modifier to ensure it's called only once during deployment/upgrade initialization.
    ///      This function should be called by the final concrete contract's `initialize` function AFTER initializing
    ///      ERC20, UUPS, and the chosen Access Control/Ownership pattern.
    /// @param name_ Token name.
    /// @param symbol_ Token symbol.
    /// @param decimals_ Token decimals.
    /// @param onchainID_ Optional on-chain identifier address.
    /// @param identityRegistry_ Address of the identity registry contract.
    /// @param compliance_ Address of the compliance contract.
    /// @param requiredClaimTopics_ Initial list of required claim topics for verification.
    /// @param initialModulePairs_ List of initial compliance modules and their parameters.
    function __SMARTUpgradeable_init(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        internal
        onlyInitializing // Ensures this logic runs only during the initialization phase
    {
        // Initialize the core SMART logic state via the base logic contract
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
        // Note: ERC20Upgradeable, UUPSUpgradeable, and AccessControl/Ownable initializers
        // must be called BEFORE this function in the final contract's initialize method.
    }

    // -- State-Changing Functions (Admin/Authorized) --

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

    // -- State-Changing Functions (Public/ERC20 Overrides) --

    /// @inheritdoc ERC20Upgradeable
    /// @dev Overrides ERC20Upgradeable.transfer to integrate SMART verification and compliance checks via hooks.
    function transfer(address to, uint256 amount) public virtual override(ERC20Upgradeable, IERC20) returns (bool) {
        address sender = _msgSender();
        // Note: We call super._transfer directly here as it calls the overridden _update internally.
        super._transfer(sender, to, amount);
        return true;
    }

    /// @inheritdoc ISMART
    /// @dev Performs multiple transfers from the caller in a single transaction.
    ///      Integrates SMART verification and compliance checks for each transfer via hooks.
    function batchTransfer(address[] calldata toList, uint256[] calldata amounts) external virtual override {
        if (toList.length != amounts.length) revert LengthMismatch();
        address sender = _msgSender();
        for (uint256 i = 0; i < toList.length; i++) {
            super._transfer(sender, toList[i], amounts[i]);
        }
    }

    // -- View Functions (ERC20 Overrides) --

    /// @inheritdoc ERC20Upgradeable
    function name() public view virtual override(ERC20Upgradeable, IERC20Metadata) returns (string memory) {
        return __name; // Return mutable name from _SMARTLogic state
    }

    /// @inheritdoc ERC20Upgradeable
    function symbol() public view virtual override(ERC20Upgradeable, IERC20Metadata) returns (string memory) {
        return __symbol; // Return mutable symbol from _SMARTLogic state
    }

    /// @inheritdoc ERC20Upgradeable
    function decimals() public view virtual override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return __decimals; // Return decimals from _SMARTLogic state
    }

    // -- Internal Hooks & Overrides --

    /**
     * @dev Overrides ERC20Upgradeable._update to centralize calls to SMART-specific hooks based on the operation type.
     * Detects mints (from == address(0)), burns (to == address(0)), and transfers.
     * Calls the corresponding `_before<Action>` and `_after<Action>` hooks defined in `SMARTHooks`,
     * which in turn call the `_smart_<action>Logic` helpers in `_SMARTLogic`.
     * Skips hooks if `__isForcedUpdate` (from `SMARTExtensionUpgradeable`) is true.
     * @param from The sender address (address(0) for mints).
     * @param to The recipient address (address(0) for burns).
     * @param value The amount being transferred/minted/burned.
     */
    function _update(address from, address to, uint256 value) internal virtual override(ERC20Upgradeable) {
        _smart_beforeUpdateLogic(from, to, value);
        super._update(from, to, value); // Perform ERC20 update
        _smart_afterUpdateLogic(from, to, value);
    }

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
