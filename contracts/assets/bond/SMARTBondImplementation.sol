// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// Constants
import { SMARTRoles } from "../SMARTRoles.sol";

// Interface imports
import { ISMARTBond } from "./ISMARTBond.sol";
import { ISMARTBurnable } from "../../extensions/burnable/ISMARTBurnable.sol";
import { SMARTComplianceModuleParamPair } from "../../interface/structs/SMARTComplianceModuleParamPair.sol";

// Core extensions
import { SMARTUpgradeable } from "../../extensions/core/SMARTUpgradeable.sol"; // Base SMART logic + ERC20
import { SMARTHooks } from "../../extensions/common/SMARTHooks.sol";

// Feature extensions
import { SMARTPausableUpgradeable } from "../../extensions/pausable/SMARTPausableUpgradeable.sol";
import { SMARTBurnableUpgradeable } from "../../extensions/burnable/SMARTBurnableUpgradeable.sol";
import { _SMARTBurnableLogic } from "../../extensions/burnable/SMARTBurnableUpgradeable.sol";
import { SMARTCustodianUpgradeable } from "../../extensions/custodian/SMARTCustodianUpgradeable.sol";
import { SMARTRedeemableUpgradeable } from "../../extensions/redeemable/SMARTRedeemableUpgradeable.sol";
import { SMARTHistoricalBalancesUpgradeable } from
    "../../extensions/historical-balances/SMARTHistoricalBalancesUpgradeable.sol";
import { SMARTYieldUpgradeable } from "../../extensions/yield/SMARTYieldUpgradeable.sol";
import { SMARTTokenAccessManagedUpgradeable } from
    "../../extensions/access-managed/SMARTTokenAccessManagedUpgradeable.sol";
import { SMARTCappedUpgradeable } from "../../extensions/capped/SMARTCappedUpgradeable.sol";
/// @title SMARTBond
/// @notice An implementation of a bond using the SMART extension framework,
///         backed by collateral and using custom roles.
/// @dev Combines core SMART features (compliance, verification) with extensions for pausing,
///      burning, custodian actions, and collateral tracking. Access control uses custom roles.

contract SMARTBondImplementation is
    Initializable,
    ISMARTBond,
    SMARTUpgradeable,
    SMARTTokenAccessManagedUpgradeable,
    SMARTCustodianUpgradeable,
    SMARTPausableUpgradeable,
    SMARTBurnableUpgradeable,
    SMARTRedeemableUpgradeable,
    SMARTHistoricalBalancesUpgradeable,
    SMARTYieldUpgradeable,
    SMARTCappedUpgradeable,
    ERC2771ContextUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /// @notice Timestamp when the bond matures
    /// @dev Set at deployment and cannot be changed
    uint256 private _maturityDate;

    /// @notice Tracks whether the bond has matured
    /// @dev Set to true when mature() is called after maturity date
    bool public isMatured;

    /// @notice The face value of the bond in underlying asset base units
    /// @dev Set at deployment and cannot be changed
    uint256 private _faceValue;

    /// @notice The underlying asset contract used for face value denomination
    /// @dev Must be a valid ERC20 token contract
    IERC20 private _underlyingAsset;

    /// @notice Tracks how many bonds each holder has redeemed
    /// @dev Maps holder address to amount of bonds redeemed
    mapping(address holder => uint256 redeemed) public bondRedeemed;

    /// @notice Emitted when the bond reaches maturity and is closed
    /// @param timestamp The block timestamp when the bond matured
    event BondMatured(uint256 indexed timestamp);

    /// @notice Emitted when a bond is redeemed for underlying assets
    /// @param sender The address that initiated the redemption
    /// @param holder The address redeeming the bonds
    /// @param bondAmount The amount of bonds redeemed
    /// @param underlyingAmount The amount of underlying assets received
    event BondRedeemed(address indexed sender, address indexed holder, uint256 bondAmount, uint256 underlyingAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @param forwarder_ The address of the forwarder contract.
    constructor(address forwarder_) ERC2771ContextUpgradeable(forwarder_) {
        _disableInitializers();
    }

    /// @notice Initializes the SMART token contract and its extensions.
    /// @param name_ The name of the token.
    /// @param symbol_ The symbol of the token.
    /// @param decimals_ The number of decimals the token uses.
    /// @param cap_ Token cap
    /// @param maturityDate_ Bond maturity date
    /// @param faceValue_ Bond face value
    /// @param underlyingAsset_ Underlying asset contract address
    /// @param requiredClaimTopics_ An array of claim topics required for token interaction.
    /// @param initialModulePairs_ Initial compliance module configurations.
    /// @param identityRegistry_ The address of the Identity Registry contract.
    /// @param compliance_ The address of the main compliance contract.
    /// @param accessManager_ The address of the access manager contract.
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 cap_,
        uint256 maturityDate_,
        uint256 faceValue_,
        address underlyingAsset_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_,
        address identityRegistry_,
        address compliance_,
        address accessManager_
    )
        external
        override
        initializer
    {
        if (maturityDate_ <= block.timestamp) revert BondInvalidMaturityDate();
        if (faceValue_ == 0) revert InvalidFaceValue();
        if (underlyingAsset_ == address(0)) revert InvalidUnderlyingAsset();

        // Verify the underlying asset contract exists by attempting to call a view function
        try IERC20(underlyingAsset_).totalSupply() returns (uint256) {
            // Contract exists and implements IERC20
        } catch {
            revert InvalidUnderlyingAsset();
        }

        __SMART_init(
            name_,
            symbol_,
            decimals_,
            address(0),
            identityRegistry_,
            compliance_,
            requiredClaimTopics_,
            initialModulePairs_
        );
        __SMARTTokenAccessManaged_init(accessManager_);
        __SMARTCustodian_init();
        __SMARTBurnable_init();
        __SMARTPausable_init();
        __SMARTYield_init();
        __SMARTRedeemable_init();
        __SMARTHistoricalBalances_init();
        __SMARTCapped_init(cap_);
        __ReentrancyGuard_init();

        _maturityDate = maturityDate_;
        _faceValue = faceValue_;
        _underlyingAsset = IERC20(underlyingAsset_);
    }

    // --- View Functions ---

    /// @notice Returns the timestamp when the bond matures
    /// @return The maturity date timestamp
    function maturityDate() external view override returns (uint256) {
        return _maturityDate;
    }

    /// @notice Returns the face value of the bond
    /// @return The bond's face value in underlying asset base units
    function faceValue() external view override returns (uint256) {
        return _faceValue;
    }

    /// @notice Returns the underlying asset contract
    /// @return The ERC20 contract of the underlying asset
    function underlyingAsset() external view override returns (IERC20) {
        return _underlyingAsset;
    }

    /// @notice Returns the amount of underlying assets held by the contract
    /// @return The balance of underlying assets
    function underlyingAssetBalance() public view override returns (uint256) {
        return _underlyingAsset.balanceOf(address(this));
    }

    /// @notice Returns the total amount of underlying assets needed for all potential redemptions
    /// @return The total amount of underlying assets needed
    function totalUnderlyingNeeded() public view override returns (uint256) {
        return _calculateUnderlyingAmount(totalSupply());
    }

    /// @notice Returns the amount of underlying assets missing for all potential redemptions
    /// @return The amount of underlying assets missing (0 if there's enough or excess)
    function missingUnderlyingAmount() public view override returns (uint256) {
        uint256 needed = totalUnderlyingNeeded();
        uint256 current = underlyingAssetBalance();
        return needed > current ? needed - current : 0;
    }

    /// @notice Returns the amount of excess underlying assets that can be withdrawn
    /// @return The amount of excess underlying assets
    function withdrawableUnderlyingAmount() public view override returns (uint256) {
        uint256 needed = totalUnderlyingNeeded();
        uint256 current = underlyingAssetBalance();
        return current > needed ? current - needed : 0;
    }

    // --- State-Changing Functions ---

    /// @notice Closes off the bond at maturity
    /// @dev Only callable by addresses with SUPPLY_MANAGEMENT_ROLE after maturity date
    /// @dev Requires sufficient underlying assets for all potential redemptions
    /// @dev TODO: check role
    function mature() external override onlyAccessManagerRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE) {
        if (block.timestamp < _maturityDate) revert BondNotYetMatured();
        if (isMatured) revert BondAlreadyMatured();

        uint256 needed = totalUnderlyingNeeded();
        if (underlyingAssetBalance() < needed) revert InsufficientUnderlyingBalance();

        isMatured = true;
        emit BondMatured(block.timestamp);
    }

    // --- ISMART Implementation ---

    function setOnchainID(address _onchainID)
        external
        override
        onlyAccessManagerRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE)
    {
        _smart_setOnchainID(_onchainID);
    }

    function setIdentityRegistry(address _identityRegistry)
        external
        override
        onlyAccessManagerRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE)
    {
        _smart_setIdentityRegistry(_identityRegistry);
    }

    function setCompliance(address _compliance)
        external
        override
        onlyAccessManagerRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE)
    {
        _smart_setCompliance(_compliance);
    }

    function setParametersForComplianceModule(
        address _module,
        bytes calldata _params
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE)
    {
        _smart_setParametersForComplianceModule(_module, _params);
    }

    function setRequiredClaimTopics(uint256[] calldata _requiredClaimTopics)
        external
        override
        onlyAccessManagerRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE)
    {
        _smart_setRequiredClaimTopics(_requiredClaimTopics);
    }

    function mint(
        address _to,
        uint256 _amount
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE)
    {
        _smart_mint(_to, _amount);
    }

    function batchMint(
        address[] calldata _toList,
        uint256[] calldata _amounts
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE)
    {
        _smart_batchMint(_toList, _amounts);
    }

    function transfer(
        address _to,
        uint256 _amount
    )
        public
        override(SMARTUpgradeable, ERC20Upgradeable, IERC20)
        returns (bool)
    {
        return _smart_transfer(_to, _amount);
    }

    function recoverERC20(
        address token,
        address to,
        uint256 amount
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.EMERGENCY_ROLE)
    {
        _smart_recoverERC20(token, to, amount);
    }

    function addComplianceModule(
        address _module,
        bytes calldata _params
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE)
    {
        _smart_addComplianceModule(_module, _params);
    }

    function removeComplianceModule(address _module)
        external
        override
        onlyAccessManagerRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE)
    {
        _smart_removeComplianceModule(_module);
    }

    // --- ISMARTBurnable Implementation ---

    function burn(
        address userAddress,
        uint256 amount
    )
        external
        override(ISMARTBurnable)
        onlyAccessManagerRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE)
    {
        _smart_burn(userAddress, amount);
    }

    function batchBurn(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        external
        override(ISMARTBurnable)
        onlyAccessManagerRole(SMARTRoles.SUPPLY_MANAGEMENT_ROLE)
    {
        _smart_batchBurn(userAddresses, amounts);
    }

    // --- ISMARTCustodian Implementation ---

    function setAddressFrozen(
        address userAddress,
        bool freeze
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.CUSTODIAN_ROLE)
    {
        _smart_setAddressFrozen(userAddress, freeze);
    }

    function freezePartialTokens(
        address userAddress,
        uint256 amount
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.CUSTODIAN_ROLE)
    {
        _smart_freezePartialTokens(userAddress, amount);
    }

    function unfreezePartialTokens(
        address userAddress,
        uint256 amount
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.CUSTODIAN_ROLE)
    {
        _smart_unfreezePartialTokens(userAddress, amount);
    }

    function batchSetAddressFrozen(
        address[] calldata userAddresses,
        bool[] calldata freeze
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.CUSTODIAN_ROLE)
    {
        _smart_batchSetAddressFrozen(userAddresses, freeze);
    }

    function batchFreezePartialTokens(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.CUSTODIAN_ROLE)
    {
        _smart_batchFreezePartialTokens(userAddresses, amounts);
    }

    function batchUnfreezePartialTokens(
        address[] calldata userAddresses,
        uint256[] calldata amounts
    )
        external
        override
        onlyAccessManagerRole(SMARTRoles.CUSTODIAN_ROLE)
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
        onlyAccessManagerRole(SMARTRoles.CUSTODIAN_ROLE)
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
        onlyAccessManagerRole(SMARTRoles.CUSTODIAN_ROLE)
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
        onlyAccessManagerRole(SMARTRoles.CUSTODIAN_ROLE)
        returns (bool)
    {
        return _smart_recoveryAddress(lostWallet, newWallet, investorOnchainID);
    }

    // --- ISMARTPausable Implementation ---

    function pause() external override onlyAccessManagerRole(SMARTRoles.EMERGENCY_ROLE) {
        _smart_pause();
    }

    function unpause() external override onlyAccessManagerRole(SMARTRoles.EMERGENCY_ROLE) {
        _smart_unpause();
    }

    // --- ISMARTYield Implementation ---

    function setYieldSchedule(address schedule)
        external
        override
        onlyAccessManagerRole(SMARTRoles.TOKEN_GOVERNANCE_ROLE)
    {
        _smart_setYieldSchedule(schedule);
    }

    function yieldBasisPerUnit(address) external view override returns (uint256) {
        return _faceValue;
    }

    function yieldToken() external view override returns (IERC20) {
        return _underlyingAsset;
    }

    // --- View Functions (Overrides) ---
    /// @inheritdoc ERC20Upgradeable
    function name() public view virtual override(ERC20Upgradeable, IERC20Metadata) returns (string memory) {
        // Delegation to SMARTUpgradeable -> _SMARTLogic ensures correct value is returned
        return super.name();
    }

    /// @inheritdoc ERC20Upgradeable
    function symbol() public view virtual override(ERC20Upgradeable, IERC20Metadata) returns (string memory) {
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

    /// @inheritdoc SMARTUpgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(SMARTUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(ISMARTBond).interfaceId || super.supportsInterface(interfaceId);
    }

    // --- Internal Functions ---

    /// @notice Calculates the underlying asset amount for a given bond amount
    /// @dev Multiplies the bond amount with the face value before dividing by decimals
    ///      to maintain precision
    /// @param bondAmount The amount of bonds to calculate for
    /// @return The amount of underlying assets
    function _calculateUnderlyingAmount(uint256 bondAmount) private view returns (uint256) {
        return (bondAmount * _faceValue) / (10 ** decimals());
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
        override(SMARTUpgradeable, SMARTCappedUpgradeable, SMARTCustodianUpgradeable, SMARTYieldUpgradeable, SMARTHooks)
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
        if (isMatured && (to != address(0))) {
            revert BondAlreadyMatured();
        }

        super._beforeTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(SMARTCustodianUpgradeable, SMARTHooks)
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
        if (!isMatured) revert BondNotYetMatured();
        if (amount <= 0) revert InvalidRedemptionAmount();

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
        super._afterBurn(from, amount);
    }

    // --- Internal Functions (Overrides) ---

    /// @notice Implementation of the abstract burn execution using the base ERC20Upgradeable `_burn` function.
    /// @dev Assumes the inheriting contract includes an ERC20Upgradeable implementation with an internal `_burn`
    /// function. Uses reentrancy protection to prevent external call exploits.
    function __redeemable_redeem(address from, uint256 amount) internal virtual override nonReentrant {
        uint256 currentBalance = balanceOf(from);

        // Simple check: user can only redeem what they currently have
        if (amount > currentBalance) revert InsufficientRedeemableBalance();

        uint256 underlyingAmount = _calculateUnderlyingAmount(amount);

        uint256 contractBalance = underlyingAssetBalance();
        if (contractBalance < underlyingAmount) {
            revert InsufficientUnderlyingBalance();
        }

        // State changes BEFORE external calls (checks-effects-interactions pattern)
        uint256 currentRedeemed = bondRedeemed[from];
        bondRedeemed[from] = currentRedeemed + amount;
        _burn(from, amount);

        // External call AFTER all state changes
        _underlyingAsset.safeTransfer(from, underlyingAmount);

        emit BondRedeemed(_msgSender(), from, amount, underlyingAmount);
    }

    /**
     * @dev Overrides _update to ensure Pausable and Collateral checks are applied.
     */
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(SMARTPausableUpgradeable, SMARTUpgradeable, ERC20Upgradeable)
    {
        // Calls chain: SMARTPausable -> ERC20Capped -> SMART -> ERC20
        super._update(from, to, value);
    }

    /// @dev Resolves msgSender across Context and SMARTPausable.
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /// @dev Resolves msgData across Context and ERC2771Context.
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    /// @dev Hook defining the length of the trusted forwarder address suffix in `msg.data`.
    function _contextSuffixLength()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }
}
