// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
// Interface imports
import { ISMART } from "../../interface/ISMART.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Base contract imports
import { SMARTExtension } from "../common/SMARTExtension.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTLogic } from "./internal/_SMARTLogic.sol";

/// @title Standard SMART Token Implementation
/// @notice Standard (non-upgradeable) implementation of the core SMART token functionality, including ERC20 compliance,
///         identity verification, and compliance checks.
/// @dev Inherits core logic from `_SMARTLogic`, authorization hooks from the chosen authorization contract (e.g.,
/// `SMARTAccessControlAuthorization`),
///      and standard OpenZeppelin `ERC20`.
///      Requires an accompanying authorization contract to be inherited for permissioned functions.
abstract contract SMART is SMARTExtension, _SMARTLogic, ERC165 {
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

    // -- Internal Hook Implementations (Dependencies) --

    /// @inheritdoc _SMARTLogic
    function __smart_executeMint(address from, uint256 amount) internal virtual override {
        _mint(from, amount);
    }

    /// @inheritdoc _SMARTLogic
    function __smart_executeTransfer(address from, address to, uint256 amount) internal virtual override {
        _transfer(from, to, amount);
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
        __smart_beforeUpdateLogic(from, to, value);
        super._update(from, to, value); // Perform ERC20 update
        __smart_afterUpdateLogic(from, to, value);
    }

    // --- Hooks ---

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
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return __smart_supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
    }
}
