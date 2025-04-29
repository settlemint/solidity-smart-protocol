// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
// --- Community Contracts ---

// Interface imports
import { ISMART } from "./interface/ISMART.sol";

// Core extensions
import { SMART } from "./extensions/core/SMART.sol"; // Base SMART logic + ERC20
import { SMARTExtension } from "./extensions/common/SMARTExtension.sol";
import { SMARTHooks } from "./extensions/common/SMARTHooks.sol";

// Feature extensions
import { SMARTPausable } from "./extensions/pausable/SMARTPausable.sol";
import { SMARTBurnable } from "./extensions/burnable/SMARTBurnable.sol";
import { SMARTCustodian } from "./extensions/custodian/SMARTCustodian.sol";
import { SMARTCollateral } from "./extensions/collateral/SMARTCollateral.sol";

// Common errors
import { Unauthorized } from "./extensions/common/CommonErrors.sol";

/// @title SMARTStableCoin
/// @notice An implementation of a stablecoin using the SMART extension framework,
///         backed by collateral and using custom roles.
/// @dev Combines core SMART features (compliance, verification) with extensions for pausing,
///      burning, custodian actions, and collateral tracking. Access control uses custom roles.
contract SMARTStableCoin is SMART, AccessControl, SMARTCollateral, SMARTCustodian, SMARTPausable, SMARTBurnable {
    uint256 public constant CLAIM_TOPIC_COLLATERAL = 3; // TODO Move these to a Constants.sol file?

    /// @notice Role identifier for addresses that can manage token supply (mint, burn, forced transfer)
    bytes32 public constant SUPPLY_MANAGEMENT_ROLE = keccak256("SUPPLY_MANAGEMENT_ROLE");

    /// @notice Role identifier for addresses that can manage users (freezing, recovery)
    bytes32 public constant USER_MANAGEMENT_ROLE = keccak256("USER_MANAGEMENT_ROLE");

    /// @notice Role identifier for addresses that can audit and update the collateral
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    /// @notice Deploys a new SMARTStableCoin token contract.
    /// @dev Initializes SMART core, AccessControl, ERC20Collateral, and grants custom roles.
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param decimals_ Token decimals
    /// @param onchainID_ Optional on-chain identifier address
    /// @param identityRegistry_ Address of the identity registry contract
    /// @param compliance_ Address of the compliance contract
    /// @param requiredClaimTopics_ Initial list of required claim topics
    /// @param initialModulePairs_ Initial list of compliance modules
    /// @param initialOwner_ Address receiving admin and operational roles
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
        // Initialize the core SMART logic (which includes ERC20)
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
        SMARTCollateral(CLAIM_TOPIC_COLLATERAL)
    {
        // Grant standard admin role
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner_);

        // Grant custom operational roles
        _grantRole(SUPPLY_MANAGEMENT_ROLE, initialOwner_); // Mint, Burn, Forced Transfer
        _grantRole(USER_MANAGEMENT_ROLE, initialOwner_); // Freeze, Recovery
        _grantRole(AUDITOR_ROLE, initialOwner_); // Update Collateral
    }

    // --- State-Changing Functions (Overrides) ---
    function transfer(address to, uint256 amount) public virtual override(SMART, ERC20, IERC20) returns (bool) {
        return super.transfer(to, amount);
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

    function hasRole(bytes32 role, address account) public view virtual override(AccessControl) returns (bool) {
        return AccessControl.hasRole(role, account);
    }

    // --- Hooks (Overrides for Chaining) ---
    // These ensure that logic from multiple inherited extensions (SMART, SMARTCustodian, etc.) is called correctly.

    /// @inheritdoc SMARTHooks
    function _beforeMint(
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMART, SMARTCollateral, SMARTCustodian, SMARTHooks)
    {
        super._beforeMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMART, SMARTCustodian, SMARTHooks)
    {
        super._beforeTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeBurn(address from, uint256 amount) internal virtual override(SMARTCustodian, SMARTHooks) {
        super._beforeBurn(from, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeRedeem(address owner, uint256 amount) internal virtual override(SMARTCustodian, SMARTHooks) {
        super._beforeRedeem(owner, amount);
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

    // --- Internal Functions (Overrides) ---

    /**
     * @dev Overrides _update to ensure Pausable and Collateral checks are applied.
     */
    function _update(address from, address to, uint256 value) internal virtual override(SMART, SMARTPausable, ERC20) {
        // Calls chain: ERC20Collateral -> SMARTPausable -> SMART -> ERC20
        super._update(from, to, value);
    }

    /// @dev Resolves msgSender across Context and SMARTPausable.
    function _msgSender() internal view virtual override(Context, SMARTPausable) returns (address) {
        return super._msgSender();
    }

    // --- Authorization Hook Implementations ---
    // Implementing the abstract functions from _SMART*AuthorizationHooks

    function _authorizeUpdateTokenSettings() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(DEFAULT_ADMIN_ROLE, sender)) revert Unauthorized(sender);
    }

    function _authorizeUpdateComplianceSettings() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(DEFAULT_ADMIN_ROLE, sender)) revert Unauthorized(sender);
    }

    function _authorizeUpdateVerificationSettings() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(DEFAULT_ADMIN_ROLE, sender)) revert Unauthorized(sender);
    }

    function _authorizeMintToken() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(SUPPLY_MANAGEMENT_ROLE, sender)) revert Unauthorized(sender);
    }

    function _authorizePause() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(DEFAULT_ADMIN_ROLE, sender)) revert Unauthorized(sender);
    }

    function _authorizeBurn() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(DEFAULT_ADMIN_ROLE, sender)) revert Unauthorized(sender);
    }

    function _authorizeFreezeAddress() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(USER_MANAGEMENT_ROLE, sender)) revert Unauthorized(sender);
    }

    function _authorizeFreezePartialTokens() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(USER_MANAGEMENT_ROLE, sender)) revert Unauthorized(sender);
    }

    function _authorizeForcedTransfer() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(SUPPLY_MANAGEMENT_ROLE, sender)) revert Unauthorized(sender);
    }

    function _authorizeRecoveryAddress() internal view virtual override {
        address sender = _msgSender();
        if (!hasRole(USER_MANAGEMENT_ROLE, sender)) revert Unauthorized(sender);
    }
}
