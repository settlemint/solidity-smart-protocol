// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Interface imports
import { ISMART } from "./interface/ISMART.sol";
import { SMARTComplianceModuleParamPair } from "./interface/structs/SMARTComplianceModuleParamPair.sol";

// Core extensions
import { SMARTUpgradeable } from "./extensions/core/SMARTUpgradeable.sol";
import { SMARTExtensionUpgradeable } from "./extensions/common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "./extensions/common/SMARTHooks.sol";

// Feature extensions
import { SMARTPausableUpgradeable } from "./extensions/pausable/SMARTPausableUpgradeable.sol";

import { SMARTBurnableUpgradeable } from "./extensions/burnable/SMARTBurnableUpgradeable.sol";

import { SMARTCustodianUpgradeable } from "./extensions/custodian/SMARTCustodianUpgradeable.sol";

import { SMARTRedeemableUpgradeable } from "./extensions/redeemable/SMARTRedeemableUpgradeable.sol";
import { SMARTCollateralUpgradeable } from "./extensions/collateral/SMARTCollateralUpgradeable.sol";
import { SMARTHistoricalBalancesUpgradeable } from
    "./extensions/historical-balances/SMARTHistoricalBalancesUpgradeable.sol";
/// @title SMARTTokenUpgradeable
/// @notice An upgradeable implementation of a SMART token with all available extensions, using UUPS proxy pattern.

contract SMARTTokenUpgradeable is
    Initializable,
    SMARTUpgradeable,
    SMARTCustodianUpgradeable,
    SMARTCollateralUpgradeable,
    SMARTPausableUpgradeable,
    SMARTBurnableUpgradeable,
    SMARTRedeemableUpgradeable,
    SMARTHistoricalBalancesUpgradeable,
    AccessControlUpgradeable
{
    // Role constants
    /// @notice Role required to update general token settings (name, symbol, onchainID).
    bytes32 public constant TOKEN_ADMIN_ROLE = keccak256("TOKEN_ADMIN_ROLE");
    /// @notice Role required to update compliance settings (compliance contract, modules, parameters).
    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");
    /// @notice Role required to update verification settings (identity registry, required claim topics).
    bytes32 public constant VERIFICATION_ADMIN_ROLE = keccak256("VERIFICATION_ADMIN_ROLE");
    /// @notice Role required to mint new tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role required to execute burn operations.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Role required to freeze/unfreeze addresses and partial token amounts.
    bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE");
    /// @notice Role required to execute forced transfers.
    bytes32 public constant FORCED_TRANSFER_ROLE = keccak256("FORCED_TRANSFER_ROLE");
    /// @notice Role required to perform address recovery.
    bytes32 public constant RECOVERY_ROLE = keccak256("RECOVERY_ROLE");

    /// @notice Role required to pause or unpause the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the SMART token contract and its extensions.
    /// @param name_ The name of the token.
    /// @param symbol_ The symbol of the token.
    /// @param decimals_ The number of decimals the token uses.
    /// @param onchainID_ The address of the OnchainID contract.
    /// @param identityRegistry_ The address of the Identity Registry contract.
    /// @param compliance_ The address of the main compliance contract.
    /// @param requiredClaimTopics_ An array of claim topics required for token interaction.
    /// @param initialModulePairs_ Initial compliance module configurations.
    /// @param initialOwner_ The initial owner of the contract.
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_,
        uint256 collateralProofTopic_,
        address initialOwner_
    )
        public
        initializer
    {
        __ERC20_init(name_, symbol_);
        __SMARTUpgradeable_init(
            name_,
            symbol_,
            decimals_,
            onchainID_,
            identityRegistry_,
            compliance_,
            requiredClaimTopics_,
            initialModulePairs_
        );
        __SMARTCustodian_init();
        __SMARTBurnable_init();
        __SMARTRedeemable_init();
        __SMARTPausable_init();
        __AccessControl_init();
        __SMARTCollateral_init(collateralProofTopic_);

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner_);
    }

    // --- ISMART Implementation ---

    function setName(string calldata _name) external override onlyRole(TOKEN_ADMIN_ROLE) {
        _smart_setName(_name);
    }

    function setSymbol(string calldata _symbol) external override onlyRole(TOKEN_ADMIN_ROLE) {
        _smart_setSymbol(_symbol);
    }

    function setOnchainID(address _onchainID) external override onlyRole(TOKEN_ADMIN_ROLE) {
        _smart_setOnchainID(_onchainID);
    }

    function setIdentityRegistry(address _identityRegistry) external override onlyRole(TOKEN_ADMIN_ROLE) {
        _smart_setIdentityRegistry(_identityRegistry);
    }

    function setCompliance(address _compliance) external override onlyRole(COMPLIANCE_ADMIN_ROLE) {
        _smart_setCompliance(_compliance);
    }

    function setParametersForComplianceModule(
        address _module,
        bytes calldata _params
    )
        external
        override
        onlyRole(COMPLIANCE_ADMIN_ROLE)
    {
        _smart_setParametersForComplianceModule(_module, _params);
    }

    function setRequiredClaimTopics(uint256[] calldata _requiredClaimTopics)
        external
        override
        onlyRole(VERIFICATION_ADMIN_ROLE)
    {
        _smart_setRequiredClaimTopics(_requiredClaimTopics);
    }

    function mint(address _to, uint256 _amount) external override onlyRole(MINTER_ROLE) {
        _smart_mint(_to, _amount);
    }

    function batchMint(
        address[] calldata _toList,
        uint256[] calldata _amounts
    )
        external
        override
        onlyRole(MINTER_ROLE)
    {
        _smart_batchMint(_toList, _amounts);
    }

    function transfer(address _to, uint256 _amount) public override(ERC20Upgradeable, IERC20) returns (bool) {
        return _smart_transfer(_to, _amount);
    }

    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external override {
        _smart_batchTransfer(_toList, _amounts);
    }

    function recoverERC20(address token, address to, uint256 amount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _smart_recoverERC20(token, to, amount);
    }

    function addComplianceModule(
        address _module,
        bytes calldata _params
    )
        external
        override
        onlyRole(COMPLIANCE_ADMIN_ROLE)
    {
        _smart_addComplianceModule(_module, _params);
    }

    function removeComplianceModule(address _module) external override onlyRole(COMPLIANCE_ADMIN_ROLE) {
        _smart_removeComplianceModule(_module);
    }

    // --- ISMARTBurnable Implementation ---

    function burn(address userAddress, uint256 amount) external override onlyRole(BURNER_ROLE) {
        _smart_burn(userAddress, amount);
    }

    function batchBurn(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        external
        override
        onlyRole(BURNER_ROLE)
    {
        _smart_batchBurn(userAddresses, amounts);
    }

    // --- ISMARTCustodian Implementation ---

    function setAddressFrozen(address userAddress, bool freeze) external override onlyRole(FREEZER_ROLE) {
        _smart_setAddressFrozen(userAddress, freeze);
    }

    function freezePartialTokens(address userAddress, uint256 amount) external override onlyRole(FREEZER_ROLE) {
        _smart_freezePartialTokens(userAddress, amount);
    }

    function unfreezePartialTokens(address userAddress, uint256 amount) external override onlyRole(FREEZER_ROLE) {
        _smart_unfreezePartialTokens(userAddress, amount);
    }

    function batchSetAddressFrozen(
        address[] calldata userAddresses,
        bool[] calldata freeze
    )
        external
        override
        onlyRole(FREEZER_ROLE)
    {
        _smart_batchSetAddressFrozen(userAddresses, freeze);
    }

    function batchFreezePartialTokens(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        external
        override
        onlyRole(FREEZER_ROLE)
    {
        _smart_batchFreezePartialTokens(userAddresses, amounts);
    }

    function batchUnfreezePartialTokens(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        external
        override
        onlyRole(FREEZER_ROLE)
    {
        _smart_batchUnfreezePartialTokens(userAddresses, amounts);
    }

    function forcedTransfer(
        address from,
        address to,
        uint256 amount
    )
        external
        override
        onlyRole(FORCED_TRANSFER_ROLE)
        returns (bool)
    {
        return _smart_forcedTransfer(from, to, amount);
    }

    function batchForcedTransfer(
        address[] calldata fromList,
        address[] calldata toList,
        uint256[] calldata amounts
    )
        external
        override
        onlyRole(FORCED_TRANSFER_ROLE)
    {
        _smart_batchForcedTransfer(fromList, toList, amounts);
    }

    function recoveryAddress(
        address lostWallet,
        address newWallet,
        address investorOnchainID
    )
        external
        override
        onlyRole(RECOVERY_ROLE)
        returns (bool)
    {
        return _smart_recoveryAddress(lostWallet, newWallet, investorOnchainID);
    }

    // --- ISMARTPausable Implementation ---

    function pause() external override onlyRole(PAUSER_ROLE) {
        _smart_pause();
    }

    function unpause() external override onlyRole(PAUSER_ROLE) {
        _smart_unpause();
    }

    // --- ISMARTRedeemable Implementation ---

    function redeem(uint256 amount) external override returns (bool) {
        return _smart_redeem(amount);
    }

    function redeemAll() external override returns (bool) {
        return _smart_redeemAll();
    }

    // --- View Functions (Overrides) ---
    /// @inheritdoc ERC20Upgradeable
    function name()
        public
        view
        virtual
        override(SMARTUpgradeable, ERC20Upgradeable, IERC20Metadata)
        returns (string memory)
    {
        // Delegation to SMARTUpgradeable -> _SMARTLogic ensures correct value is returned
        return super.name();
    }

    /// @inheritdoc ERC20Upgradeable
    function symbol()
        public
        view
        virtual
        override(SMARTUpgradeable, ERC20Upgradeable, IERC20Metadata)
        returns (string memory)
    {
        // Delegation to SMARTUpgradeable -> _SMARTLogic ensures correct value is returned
        return super.symbol();
    }

    /// @inheritdoc SMARTUpgradeable
    /// @dev Need to explicitly override because ERC20Upgradeable also defines decimals().
    /// Ensures we read the value set by __SMART_init_unchained via _SMARTLogic.
    function decimals()
        public
        view
        virtual
        override(SMARTUpgradeable, ERC20Upgradeable, IERC20Metadata)
        returns (uint8)
    {
        // Delegation to SMARTUpgradeable -> _SMARTLogic ensures correct value is returned
        return super.decimals();
    }

    /// @dev Overrides ERC165 to ensure that the SMART implementation is used.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(SMARTUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Overrides required due to diamond inheritance involving ERC20Pausable and SMARTExtension/ERC20.
     * We explicitly call the Pausable implementation which includes the `whenNotPaused` check.
     */
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(SMARTUpgradeable, SMARTPausableUpgradeable, ERC20Upgradeable)
    {
        // Note: SMARTUpgradeable also overrides _update, but SMARTPausable's takes precedence for the pause check.
        // Both eventually call ERC20Upgradeable._update
        super._update(from, to, value);
    }

    // --- Overrides for Hook Functions ---
    // These overrides ensure that hooks from all relevant extensions are called in a defined order.

    /// @inheritdoc SMARTHooks
    function _beforeMint(
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTUpgradeable, SMARTCollateralUpgradeable, SMARTCustodianUpgradeable, SMARTHooks)
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
        override(SMARTUpgradeable, SMARTCustodianUpgradeable, SMARTHooks)
    {
        super._beforeTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(SMARTCustodianUpgradeable, SMARTHooks) // SMARTUpgradeable
            // does not implement _beforeBurn
    {
        super._beforeBurn(from, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeRedeem(
        address owner,
        uint256 amount
    )
        internal
        virtual
        override(SMARTCustodianUpgradeable, SMARTHooks)
    {
        super._beforeRedeem(owner, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterMint(
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTUpgradeable, SMARTHistoricalBalancesUpgradeable, SMARTHooks)
    {
        // SMARTCustodianUpgradeable, SMARTPausableUpgradeable, SMARTBurnableUpgradeable do not implement _afterMint
        super._afterMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTUpgradeable, SMARTHistoricalBalancesUpgradeable, SMARTHooks)
    // SMARTCustodianUpgradeable, SMARTPausableUpgradeable, SMARTBurnableUpgradeable do not implement _afterTransfer
    {
        super._afterTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(SMARTUpgradeable, SMARTHistoricalBalancesUpgradeable, SMARTHooks)
    {
        // SMARTCustodianUpgradeable, SMARTPausableUpgradeable do not implement _afterBurn
        super._afterBurn(from, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterRedeem(address owner, uint256 amount) internal virtual override(SMARTHooks) {
        super._afterRedeem(owner, amount);
    }

    /// @dev Overrides required due to conflict with ContextUpgradeable inherited via multiple paths.
    function _msgSender() internal view virtual override(ContextUpgradeable) returns (address) {
        return super._msgSender();
    }
}
