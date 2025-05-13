// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
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
abstract contract SMARTUpgradeable is Initializable, SMARTExtensionUpgradeable, ERC165Upgradeable, _SMARTLogic {
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
        __ERC20_init(name_, symbol_);
        // Initialize the core SMART logic state via the base logic contract
        __SMART_init_unchained(
            decimals_, onchainID_, identityRegistry_, compliance_, requiredClaimTopics_, initialModulePairs_
        );
        // Note: ERC20Upgradeable, UUPSUpgradeable, and AccessControl/Ownable initializers
        // must be called BEFORE this function in the final contract's initialize method.
    }

    function transfer(address to, uint256 amount) public virtual override(ERC20Upgradeable, IERC20) returns (bool) {
        return _smart_transfer(to, amount);
    }

    function batchTransfer(address[] calldata toList, uint256[] calldata amounts) external virtual override {
        _smart_batchTransfer(toList, amounts);
    }

    // -- Internal Hook Implementations (Dependencies) --

    /// @inheritdoc _SMARTLogic
    function __smart_executeMint(address from, uint256 amount) internal virtual override {
        _mint(from, amount);
    }

    /// @inheritdoc _SMARTLogic
    function __smart_executeTransfer(address from, address to, uint256 amount) internal virtual override {
        _transfer(from, to, amount);
    }

    // -- View Functions (ERC20 Overrides) --

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
        __smart_beforeUpdateLogic(from, to, value);
        super._update(from, to, value); // Perform ERC20 update
        __smart_afterUpdateLogic(from, to, value);
    }

    /// @inheritdoc SMARTHooks
    /// @dev Calls the core SMART minting logic check before proceeding.
    function _beforeMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        __smart_beforeMintLogic(to, amount);
        super._beforeMint(to, amount); // Allow further extension hooks
    }

    /// @inheritdoc SMARTHooks
    /// @dev Calls the core SMART minting logic notification after completion.
    function _afterMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        __smart_afterMintLogic(to, amount);
        super._afterMint(to, amount); // Allow further extension hooks
    }

    /// @inheritdoc SMARTHooks
    /// @dev Calls the core SMART transfer logic check before proceeding.
    function _beforeTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        __smart_beforeTransferLogic(from, to, amount);
        super._beforeTransfer(from, to, amount); // Allow further extension hooks
    }

    /// @inheritdoc SMARTHooks
    /// @dev Calls the core SMART transfer logic notification after completion.
    function _afterTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        __smart_afterTransferLogic(from, to, amount);
        super._afterTransfer(from, to, amount); // Allow further extension hooks
    }

    /// @inheritdoc SMARTHooks
    /// @dev Calls the core SMART burn logic notification after completion.
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        __smart_afterBurnLogic(from, amount);
        super._afterBurn(from, amount); // Allow further extension hooks
    }

    /**
     * @notice Standard ERC165 function to check if the contract supports an interface.
     * @dev This implementation checks against the internally registered interfaces.
     * Derived contracts may want to override this to include statically supported interfaces
     * (e.g., `type(IERC165).interfaceId`) or combine with this base logic.
     * It's recommended that derived contracts call `_registerInterface(type(IERC165).interfaceId)`
     * in their constructor if they intend to support ERC165 introspection for themselves.
     *
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return `true` if the contract implements `interfaceId` and `interfaceId` is not 0xffffffff, `false` otherwise.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
        return __smart_supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
    }
}
