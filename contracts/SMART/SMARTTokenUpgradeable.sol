// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { SMARTUpgradeable } from "./extensions/upgradeable/SMARTUpgradeable.sol";
import { SMARTPausableUpgradeable } from "./extensions/upgradeable/SMARTPausableUpgradeable.sol";
import { SMARTBurnableUpgradeable } from "./extensions/upgradeable/SMARTBurnableUpgradeable.sol";
import { SMARTCustodianUpgradeable } from "./extensions/upgradeable/SMARTCustodianUpgradeable.sol";
import { SMARTExtensionUpgradeable } from "./extensions/upgradeable/SMARTExtensionUpgradeable.sol";
import { ISMART } from "./interface/ISMART.sol"; // Assuming ISMART interface is compatible
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title SMARTTokenUpgradeable
/// @notice An upgradeable implementation of a SMART token with all available extensions, using UUPS proxy pattern.
contract SMARTTokenUpgradeable is
    Initializable,
    UUPSUpgradeable,
    SMARTUpgradeable,
    SMARTCustodianUpgradeable,
    SMARTPausableUpgradeable,
    SMARTBurnableUpgradeable
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
        ISMART.ComplianceModuleParamPair[] memory initialModulePairs_,
        address initialOwner_
    )
        public
        initializer
    {
        // --- Call internal initializers in dependency order ---

        // 1. Initialize Ownable first (inherited via multiple paths, call once)
        __Ownable_init(initialOwner_);

        // 2. Initialize ERC20 basic features
        // Note: name/symbol/decimals state is primarily managed by _SMARTLogic via __SMART_init_unchained,
        // but calling __ERC20_init is standard practice for its setup.
        __ERC20_init(name_, symbol_);

        // 3. Initialize the core SMART logic state via SMARTUpgradeable's internal initializer
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

        // 4. Initialize Extensions (order among these usually doesn't matter)
        // Check if SMARTExtensionUpgradeable.sol has an initializer like __SMARTExtension_init() and call if necessary.
        // __SMARTExtension_init(); // Uncomment if SMARTExtensionUpgradeable needs initialization
        __SMARTCustodian_init();
        __SMARTPausable_init(); // Internally calls __Pausable_init
        __SMARTBurnable_init();

        // 5. Initialize UUPS (must be after Ownable is initialized)
        __UUPSUpgradeable_init();
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

    /// @inheritdoc ERC20Upgradeable
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        virtual
        override(SMARTUpgradeable, ERC20Upgradeable, IERC20)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
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
        override(SMARTPausableUpgradeable, ERC20Upgradeable)
    {
        // Note: SMARTUpgradeable also overrides _update, but SMARTPausable's takes precedence for the pause check.
        // Both eventually call ERC20Upgradeable._update
        super._update(from, to, value);
    }

    // --- Overrides for Hook Functions ---
    // These overrides ensure that hooks from all relevant extensions are called in a defined order.

    /// @inheritdoc SMARTExtensionUpgradeable
    function _validateMint(
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTUpgradeable, SMARTPausableUpgradeable, SMARTCustodianUpgradeable, SMARTExtensionUpgradeable)
    {
        super._validateMint(to, amount);
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _validateTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTUpgradeable, SMARTPausableUpgradeable, SMARTCustodianUpgradeable, SMARTExtensionUpgradeable)
    {
        super._validateTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _validateBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(SMARTBurnableUpgradeable, SMARTCustodianUpgradeable, SMARTExtensionUpgradeable) // SMARTUpgradeable
            // does not implement _validateBurn
    {
        super._validateBurn(from, amount);
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _afterMint(
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTUpgradeable, SMARTExtensionUpgradeable)
    {
        // SMARTCustodianUpgradeable, SMARTPausableUpgradeable, SMARTBurnableUpgradeable do not implement _afterMint
        super._afterMint(to, amount);
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _afterTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTUpgradeable, SMARTExtensionUpgradeable)
    // SMARTCustodianUpgradeable, SMARTPausableUpgradeable, SMARTBurnableUpgradeable do not implement _afterTransfer
    {
        super._afterTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _afterBurn(
        address from,
        uint256 amount
    )
        internal
        virtual
        override(SMARTUpgradeable, SMARTBurnableUpgradeable, SMARTExtensionUpgradeable)
    {
        // SMARTCustodianUpgradeable, SMARTPausableUpgradeable do not implement _afterBurn
        super._afterBurn(from, amount);
    }

    // --- UUPS Upgradeability ---

    /// @dev Authorizes an upgrade for the contract. Restricted to the owner.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override(SMARTUpgradeable, UUPSUpgradeable)
        onlyOwner
    { }

    // Gap for future storage variables to allow safer upgrades.
    uint256[50] private __gap;
}
