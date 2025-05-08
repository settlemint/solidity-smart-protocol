// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
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
import { SMARTAccessControlAuthorization } from "./extensions/core/SMARTAccessControlAuthorization.sol";
import { SMARTExtensionAccessControlAuthorization } from
    "./extensions/common/SMARTExtensionAccessControlAuthorization.sol";

// Feature extensions
import { SMARTPausableUpgradeable } from "./extensions/pausable/SMARTPausableUpgradeable.sol";
import { SMARTPausableAccessControlAuthorization } from
    "./extensions/pausable/SMARTPausableAccessControlAuthorization.sol";
import { SMARTBurnableUpgradeable } from "./extensions/burnable/SMARTBurnableUpgradeable.sol";
import { SMARTBurnableAccessControlAuthorization } from
    "./extensions/burnable/SMARTBurnableAccessControlAuthorization.sol";
import { SMARTCustodianUpgradeable } from "./extensions/custodian/SMARTCustodianUpgradeable.sol";
import { SMARTCustodianAccessControlAuthorization } from
    "./extensions/custodian/SMARTCustodianAccessControlAuthorization.sol";
import { SMARTRedeemableUpgradeable } from "./extensions/redeemable/SMARTRedeemableUpgradeable.sol";
import { SMARTCollateralUpgradeable } from "./extensions/collateral/SMARTCollateralUpgradeable.sol";

/// @title SMARTTokenUpgradeable
/// @notice An upgradeable implementation of a SMART token with all available extensions, using UUPS proxy pattern.
contract SMARTTokenUpgradeable is
    Initializable,
    UUPSUpgradeable,
    SMARTUpgradeable,
    SMARTAccessControlAuthorization,
    SMARTBurnableAccessControlAuthorization,
    SMARTPausableAccessControlAuthorization,
    SMARTCustodianAccessControlAuthorization,
    SMARTCustodianUpgradeable,
    SMARTCollateralUpgradeable,
    SMARTPausableUpgradeable,
    SMARTBurnableUpgradeable,
    SMARTRedeemableUpgradeable,
    AccessControlUpgradeable
{
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
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __SMARTCollateral_init(collateralProofTopic_);

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner_);
        // _grantRole(BURNER_ROLE, initialOwner_);
        // _grantRole(MINTER_ROLE, initialOwner_);
        // _grantRole(COMPLIANCE_ADMIN_ROLE, initialOwner_);
        // _grantRole(VERIFICATION_ADMIN_ROLE, initialOwner_);
        // _grantRole(TOKEN_ADMIN_ROLE, initialOwner_);
        // _grantRole(FREEZER_ROLE, initialOwner_);
        // _grantRole(FORCED_TRANSFER_ROLE, initialOwner_);
        // _grantRole(RECOVERY_ROLE, initialOwner_);
        // _grantRole(PAUSER_ROLE, initialOwner_);
    }

    // --- Overrides for Conflicting Functions ---

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

    /// @inheritdoc ERC20Upgradeable
    function transfer(
        address to,
        uint256 amount
    )
        public
        virtual
        override(SMARTUpgradeable, ERC20Upgradeable, IERC20)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function hasRole(
        bytes32 role,
        address account
    )
        public
        view
        override(SMARTExtensionAccessControlAuthorization, AccessControlUpgradeable)
        returns (bool)
    {
        return super.hasRole(role, account);
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
        override(SMARTRedeemableUpgradeable, SMARTCustodianUpgradeable, SMARTHooks)
    {
        super._beforeRedeem(owner, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterMint(address to, uint256 amount) internal virtual override(SMARTUpgradeable, SMARTHooks) {
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
        override(SMARTUpgradeable, SMARTHooks)
    // SMARTCustodianUpgradeable, SMARTPausableUpgradeable, SMARTBurnableUpgradeable do not implement _afterTransfer
    {
        super._afterTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTUpgradeable, SMARTHooks) {
        // SMARTCustodianUpgradeable, SMARTPausableUpgradeable do not implement _afterBurn
        super._afterBurn(from, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterRedeem(
        address owner,
        uint256 amount
    )
        internal
        virtual
        override(SMARTRedeemableUpgradeable, SMARTHooks)
    {
        super._afterRedeem(owner, amount);
    }

    /// @dev Overrides required due to conflict with ContextUpgradeable inherited via multiple paths.
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, SMARTExtensionAccessControlAuthorization)
        returns (address)
    {
        return super._msgSender();
    }

    // --- UUPS Upgradeability ---

    /// @dev Authorizes an upgrade for the contract. Restricted to the owner.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override(UUPSUpgradeable)
        onlyRole(DEFAULT_ADMIN_ROLE)
    { }

    // Gap for future storage variables to allow safer upgrades.
    uint256[50] private __gap;
}
