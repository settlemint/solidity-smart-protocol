// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface imports
import { ISMART } from "./interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "./interface/ISMARTIdentityRegistry.sol";
import { ISMARTCompliance } from "./interface/ISMARTCompliance.sol";
import { SMARTComplianceModuleParamPair } from "./interface/structs/SMARTComplianceModuleParamPair.sol";

// Core extensions
import { SMART } from "./extensions/core/SMART.sol";
import { SMARTExtension } from "./extensions/common/SMARTExtension.sol";
import { SMARTHooks } from "./extensions/common/SMARTHooks.sol";

// Feature extensions
import { SMARTPausable } from "./extensions/pausable/SMARTPausable.sol";
import { SMARTBurnable } from "./extensions/burnable/SMARTBurnable.sol";
import { SMARTCustodian } from "./extensions/custodian/SMARTCustodian.sol";
import { SMARTRedeemable } from "./extensions/redeemable/SMARTRedeemable.sol";
import { SMARTCollateral } from "./extensions/collateral/SMARTCollateral.sol";
import { SMARTHistoricalBalances } from "./extensions/historical-balances/SMARTHistoricalBalances.sol";

/// @title SMARTToken
/// @notice A complete implementation of a SMART token with all available extensions
contract SMARTToken is
    SMART,
    SMARTCustodian,
    SMARTCollateral,
    SMARTPausable,
    SMARTBurnable,
    SMARTRedeemable,
    SMARTHistoricalBalances,
    AccessControl
{
    using SafeERC20 for IERC20;

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

    constructor(
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
        SMARTCustodian()
        SMARTCollateral(collateralProofTopic_)
        SMARTPausable()
        SMARTBurnable()
        SMARTRedeemable()
        SMARTHistoricalBalances()
    {
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

    function transfer(address _to, uint256 _amount) public override(SMART, ERC20, IERC20) returns (bool) {
        return _smart_transfer(_to, _amount);
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

    /// @dev Overrides ERC165 to ensure that the SMART implementation is used.
    function supportsInterface(bytes4 interfaceId) public view virtual override(SMART, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // --- Hooks ---

    /// @inheritdoc SMARTHooks
    function _beforeUpdate(
        address sender,
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTCustodian, SMARTCollateral, SMARTHooks)
    {
        super._beforeUpdate(sender, from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterUpdate(
        address sender,
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTHistoricalBalances, SMARTHooks)
    {
        super._afterUpdate(sender, from, to, amount);
    }

    // --- Internal Functions (Overrides) ---
    /**
     * @dev Explicitly call the Pausable implementation which includes the `whenNotPaused` check.
     */
    function _update(address from, address to, uint256 value) internal virtual override(SMART, SMARTPausable, ERC20) {
        super._update(from, to, value);
    }

    function _msgSender() internal view virtual override(Context) returns (address) {
        return Context._msgSender();
    }
}
