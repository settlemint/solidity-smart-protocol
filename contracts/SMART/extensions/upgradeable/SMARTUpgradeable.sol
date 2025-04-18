// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol"; // Import
    // UUPSUpgradeable
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // For override specifier
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol"; // For override
    // specifier
// Use upgradeable extension base
import { SMARTExtensionUpgradeable } from "./SMARTExtensionUpgradeable.sol";
// Import the base logic contract
import { _SMARTLogic } from "../base/_SMARTLogic.sol";
// Import ISMART just for @inheritdoc tags if needed (though _SMARTLogic implements it)
import { ISMART } from "../../interface/ISMART.sol";
import { LengthMismatch } from "../common/CommonErrors.sol";

/// @title SMARTUpgradeable
/// @notice Upgradeable implementation of the core SMART token functionality using UUPS proxy pattern.
/// @dev Inherits core logic from _SMARTLogic and upgradeable OZ contracts.
abstract contract SMARTUpgradeable is
    Initializable,
    SMARTExtensionUpgradeable, // Use upgradeable extension base
    OwnableUpgradeable, // Use upgradeable Ownable
    UUPSUpgradeable, // Inherit UUPSUpgradeable for _authorizeUpgrade
    _SMARTLogic // Base logic containing state and core functions
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // Prevent implementation contract initialization
    }

    // --- Initializer ---
    /// @dev Initializes the contract, setting up ERC20, Ownable, and SMART logic.
    ///      This replaces the constructor for upgradeable contracts.
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address initialOwner_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        ComplianceModuleParamPair[] memory initialModulePairs_
    )
        public
        virtual
        initializer // Locks this function after first call
    {
        // Initialize parent contracts
        __Ownable_init(initialOwner_); // Initialize Ownable
        __ERC20_init(name_, symbol_); // Initialize ERC20 - Note: Uses OZ internal storage
        __UUPSUpgradeable_init(); // Initialize UUPS
        __SMARTExtension_init(); // Placeholder if SMARTExtensionUpgradeable needs init

        // Initialize SMART logic state via the base contract's internal initializer
        // This sets __name, __symbol, __decimals, etc. in _SMARTLogic's storage
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
        // Note: Event emission happens within __SMART_init_unchained
    }

    // --- State-Changing Functions ---
    // Implement functions from ISMART (via _SMARTLogic) and potentially override OZ functions

    /// @inheritdoc ISMART
    function setName(string calldata name_) external virtual override onlyOwner {
        _setName(name_); // Calls _SMARTLogic's internal _setName
    }

    /// @inheritdoc ISMART
    function setSymbol(string calldata symbol_) external virtual override onlyOwner {
        _setSymbol(symbol_); // Calls _SMARTLogic's internal _setSymbol
    }

    /// @inheritdoc ISMART
    function setOnchainID(address onchainID_) external virtual override onlyOwner {
        _setOnchainID(onchainID_); // Call internal logic from base
    }

    /// @inheritdoc ISMART
    function setIdentityRegistry(address identityRegistry_) external virtual override onlyOwner {
        _setIdentityRegistry(identityRegistry_); // Call internal logic from base
    }

    /// @inheritdoc ISMART
    function setCompliance(address compliance_) external virtual override onlyOwner {
        _setCompliance(compliance_); // Call internal logic from base
    }

    /// @inheritdoc ISMART
    /// @dev Requires owner privileges.
    function mint(address to, uint256 amount) external virtual override onlyOwner {
        _validateMint(to, amount); // Calls SMARTExtensionUpgradeable -> _SMARTLogic validation
        _mint(to, amount); // Calls ERC20Upgradeable _mint
        _afterMint(to, amount); // Calls SMARTExtensionUpgradeable -> _SMARTLogic hooks
    }

    /// @inheritdoc ISMART
    /// @dev Requires owner privileges.
    function batchMint(address[] calldata toList, uint256[] calldata amounts) external virtual override onlyOwner {
        if (toList.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < toList.length; i++) {
            // Use internal functions
            _validateMint(toList[i], amounts[i]);
            _mint(toList[i], amounts[i]); // Use ERC20Upgradeable internal _mint
            _afterMint(toList[i], amounts[i]);
        }
    }

    /// @inheritdoc ERC20Upgradeable
    /// @dev Overrides ERC20Upgradeable.transfer to include SMART validation and hooks.
    function transfer(address to, uint256 amount) public virtual override(ERC20Upgradeable, IERC20) returns (bool) {
        address sender = _msgSender();
        _validateTransfer(sender, to, amount); // Calls SMARTExtensionUpgradeable -> _SMARTLogic validation
        super._transfer(sender, to, amount); // Call ERC20Upgradeable's _transfer
        _afterTransfer(sender, to, amount); // Calls SMARTExtensionUpgradeable -> _SMARTLogic hooks
        return true;
    }

    /// @inheritdoc ISMART
    function batchTransfer(address[] calldata toList, uint256[] calldata amounts) external virtual override {
        if (toList.length != amounts.length) revert LengthMismatch();
        address sender = _msgSender(); // Cache sender
        for (uint256 i = 0; i < toList.length; i++) {
            // Use internal functions for consistency and efficiency
            _validateTransfer(sender, toList[i], amounts[i]);
            super._transfer(sender, toList[i], amounts[i]); // Call ERC20Upgradeable's internal transfer
            _afterTransfer(sender, toList[i], amounts[i]);
        }
    }

    /// @inheritdoc ERC20Upgradeable
    /// @dev Overrides ERC20Upgradeable.transferFrom to include SMART validation and hooks.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        virtual
        override(ERC20Upgradeable, IERC20)
        returns (bool)
    {
        address spender = _msgSender();
        _validateTransfer(from, to, amount); // Calls SMARTExtensionUpgradeable -> _SMARTLogic validation
        super._spendAllowance(from, spender, amount); // Call ERC20Upgradeable's _spendAllowance
        super._transfer(from, to, amount); // Call ERC20Upgradeable's _transfer
        _afterTransfer(from, to, amount); // Calls SMARTExtensionUpgradeable -> _SMARTLogic hooks
        return true;
    }

    /// @inheritdoc ISMART
    function addComplianceModule(address module, bytes calldata params) external virtual override onlyOwner {
        _addComplianceModule(module, params); // Call internal logic from base
    }

    /// @inheritdoc ISMART
    function removeComplianceModule(address module) external virtual override onlyOwner {
        _removeComplianceModule(module); // Call internal logic from base
    }

    /// @inheritdoc ISMART
    function setParametersForComplianceModule(
        address module,
        bytes calldata params
    )
        external
        virtual
        override
        onlyOwner
    {
        _setParametersForComplianceModule(module, params); // Call internal logic from base
    }

    // --- View Functions ---
    // View functions (name, symbol, decimals, onchainID, etc.) are inherited from _SMARTLogic.
    // We need to override name, symbol, decimals here because ERC20Upgradeable also defines them,
    // and Solidity requires explicit override for all bases.

    /// @inheritdoc ERC20Upgradeable
    function name()
        public
        view
        virtual
        override(ERC20Upgradeable, _SMARTLogic, IERC20Metadata)
        returns (string memory)
    {
        return super.name(); // Delegate to _SMARTLogic's implementation via inheritance
    }

    /// @inheritdoc ERC20Upgradeable
    function symbol()
        public
        view
        virtual
        override(ERC20Upgradeable, _SMARTLogic, IERC20Metadata)
        returns (string memory)
    {
        return super.symbol(); // Delegate to _SMARTLogic's implementation via inheritance
    }

    /// @inheritdoc ERC20Upgradeable
    function decimals() public view virtual override(ERC20Upgradeable, _SMARTLogic, IERC20Metadata) returns (uint8) {
        return super.decimals(); // Delegate to _SMARTLogic's implementation via inheritance
    }

    // --- Internal Functions ---
    // Internal hooks (_validate*, _after*) inherit SMARTExtensionUpgradeable and call _SMARTLogic via super.

    /// @inheritdoc SMARTExtensionUpgradeable
    function _validateMint(address to, uint256 amount) internal virtual override(SMARTExtensionUpgradeable) {
        _smart_validateMintLogic(to, amount); // Call renamed helper from _SMARTLogic
        super._validateMint(to, amount);
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _afterMint(address to, uint256 amount) internal virtual override(SMARTExtensionUpgradeable) {
        _smart_afterMintLogic(to, amount); // Call renamed helper from _SMARTLogic
        super._afterMint(to, amount);
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _validateTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTExtensionUpgradeable)
    {
        _smart_validateTransferLogic(from, to, amount); // Call renamed helper from _SMARTLogic
        super._validateTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _afterTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(SMARTExtensionUpgradeable)
    {
        _smart_afterTransferLogic(from, to, amount); // Call renamed helper from _SMARTLogic
        super._afterTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTExtensionUpgradeable
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTExtensionUpgradeable) {
        _smart_afterBurnLogic(from, amount); // Call renamed helper from _SMARTLogic
        super._afterBurn(from, amount);
    }

    // --- Upgradeability Requirement ---
    // Required by OZ UUPSUpgradeable pattern if using UUPS
    function _authorizeUpgrade(address newImplementation) internal override(UUPSUpgradeable) onlyOwner { }

    // --- Gap for upgradeability ---
    // Leave a gap for future storage variables to avoid storage collisions.
    uint256[50] private __gap;

    // --- Internal Initializer Placeholder ---
    // If SMARTExtensionUpgradeable needs its own initializer logic
    function __SMARTExtension_init() internal onlyInitializing { }
}
