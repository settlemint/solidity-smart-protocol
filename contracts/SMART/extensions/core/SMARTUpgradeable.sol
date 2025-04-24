// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Interface imports
import { ISMART } from "../../interface/ISMART.sol";

// Base contract imports
import { SMARTExtensionUpgradeable } from "./../common/SMARTExtensionUpgradeable.sol";
import { SMARTHooks } from "../common/SMARTHooks.sol";

// Internal implementation imports
import { _SMARTLogic } from "./internal/_SMARTLogic.sol";

// Error imports
import { LengthMismatch } from "../common/CommonErrors.sol";

/// @title SMARTUpgradeable
/// @notice Upgradeable implementation of the core SMART token functionality using UUPS proxy pattern.
/// @dev Inherits core logic from _SMARTLogic and upgradeable OZ contracts.
abstract contract SMARTUpgradeable is Initializable, SMARTExtensionUpgradeable, UUPSUpgradeable, _SMARTLogic {
    // --- Constructor ---
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // Prevent implementation contract initialization
    }

    // --- Initializer ---
    /// @dev Internal initializer for SMARTUpgradeable state.
    ///      Initializes the core SMART logic via _SMARTLogic's initializer.
    ///      Should be called by the final concrete contract's initialize function.
    function __SMARTUpgradeable_init(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        ComplianceModuleParamPair[] memory initialModulePairs_
    )
        internal
        onlyInitializing
    {
        __SMARTExtension_init();

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
    }

    // --- State-Changing Functions ---

    /// @inheritdoc ISMART
    function setName(string calldata name_) external virtual override {
        _setName(name_);
    }

    /// @inheritdoc ISMART
    function setSymbol(string calldata symbol_) external virtual override {
        _setSymbol(symbol_);
    }

    /// @inheritdoc ISMART
    function setOnchainID(address onchainID_) external virtual override {
        _setOnchainID(onchainID_);
    }

    /// @inheritdoc ISMART
    function setIdentityRegistry(address identityRegistry_) external virtual override {
        _setIdentityRegistry(identityRegistry_);
    }

    /// @inheritdoc ISMART
    function setCompliance(address compliance_) external virtual override {
        _setCompliance(compliance_);
    }

    /// @inheritdoc ISMART
    /// @dev Requires owner privileges.
    function mint(address to, uint256 amount) external virtual override {
        _beforeMint(to, amount);
        _mint(to, amount);
        _afterMint(to, amount);
    }

    /// @inheritdoc ISMART
    /// @dev Requires owner privileges.
    function batchMint(address[] calldata toList, uint256[] calldata amounts) external virtual override {
        if (toList.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < toList.length; i++) {
            _beforeMint(toList[i], amounts[i]);
            _mint(toList[i], amounts[i]);
            _afterMint(toList[i], amounts[i]);
        }
    }

    /// @inheritdoc ERC20Upgradeable
    /// @dev Overrides ERC20Upgradeable.transfer to include SMART validation and hooks.
    function transfer(address to, uint256 amount) public virtual override(ERC20Upgradeable, IERC20) returns (bool) {
        address sender = _msgSender();
        _beforeTransfer(sender, to, amount, false);
        super._transfer(sender, to, amount);
        _afterTransfer(sender, to, amount);
        return true;
    }

    /// @inheritdoc ISMART
    function batchTransfer(address[] calldata toList, uint256[] calldata amounts) external virtual override {
        if (toList.length != amounts.length) revert LengthMismatch();
        address sender = _msgSender();
        for (uint256 i = 0; i < toList.length; i++) {
            _beforeTransfer(sender, toList[i], amounts[i], false);
            super._transfer(sender, toList[i], amounts[i]);
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
        _beforeTransfer(from, to, amount, false);
        super._spendAllowance(from, spender, amount);
        super._transfer(from, to, amount);
        _afterTransfer(from, to, amount);
        return true;
    }

    /// @inheritdoc ISMART
    function addComplianceModule(address module, bytes calldata params) external virtual override {
        _addComplianceModule(module, params);
    }

    /// @inheritdoc ISMART
    function removeComplianceModule(address module) external virtual override {
        _removeComplianceModule(module);
    }

    /// @inheritdoc ISMART
    function setParametersForComplianceModule(address module, bytes calldata params) external virtual override {
        _setParametersForComplianceModule(module, params);
    }

    // --- View Functions ---

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

    // --- Hooks ---

    /// @inheritdoc SMARTHooks
    function _beforeMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _smart_beforeMintLogic(to, amount); // Call helper from base logic
        super._beforeMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        _smart_afterMintLogic(to, amount); // Call helper from base logic
        super._afterMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _beforeTransfer(
        address from,
        address to,
        uint256 amount,
        bool forced
    )
        internal
        virtual
        override(SMARTHooks)
    {
        _smart_beforeTransferLogic(from, to, amount, forced); // Call helper from base logic
        super._beforeTransfer(from, to, amount, forced);
    }

    /// @inheritdoc SMARTHooks
    function _afterTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        _smart_afterTransferLogic(from, to, amount); // Call helper from base logic
        super._afterTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        _smart_afterBurnLogic(from, amount); // Call helper from base logic
        super._afterBurn(from, amount);
    }

    // --- Gap ---
    /// @dev Gap for upgradeability.
    uint256[50] private __gap;

    // --- Internal Functions ---
    /// @dev Placeholder for potential SMARTExtensionUpgradeable initializer logic.
    function __SMARTExtension_init() internal onlyInitializing { }
}
