// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISMART } from "../interface/ISMART.sol";
import { SMARTExtension } from "./SMARTExtension.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { LengthMismatch } from "./common/CommonErrors.sol";
import { _SMARTLogic } from "./base/_SMARTLogic.sol";
import { SMARTHooks } from "./common/SMARTHooks.sol";

/// @title SMART
/// @notice Standard (non-upgradeable) implementation of the core SMART token functionality.
/// @dev Inherits core logic from _SMARTLogic and standard OZ contracts.
abstract contract SMART is SMARTExtension, Ownable, _SMARTLogic {
    // --- Custom Errors ---
    // Errors are inherited from _SMARTLogic

    // --- Storage Variables ---
    // State variables are inherited from _SMARTLogic (prefixed with __)
    // Note: immutable _decimals removed, now stored in __decimals

    // --- Events ---
    // Events are inherited from _SMARTLogic

    // --- Constructor ---
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        ComplianceModuleParamPair[] memory initialModulePairs_,
        address initialOwner_
    )
        ERC20(name_, symbol_)
        Ownable(initialOwner_)
    {
        // Initialize the core SMART logic state
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
    function setName(string calldata name_) external virtual override onlyOwner {
        _setName(name_);
    }

    /// @inheritdoc ISMART
    function setSymbol(string calldata symbol_) external virtual override onlyOwner {
        _setSymbol(symbol_);
    }

    /// @inheritdoc ISMART
    function setOnchainID(address onchainID_) external virtual override onlyOwner {
        _setOnchainID(onchainID_);
    }

    /// @inheritdoc ISMART
    function setIdentityRegistry(address identityRegistry_) external virtual override onlyOwner {
        _setIdentityRegistry(identityRegistry_);
    }

    /// @inheritdoc ISMART
    function setCompliance(address compliance_) external virtual override onlyOwner {
        _setCompliance(compliance_);
    }

    /// @inheritdoc ISMART
    /// @dev Requires owner privileges.
    function mint(address to, uint256 amount) external virtual override onlyOwner {
        _beforeMint(to, amount);
        _mint(to, amount);
        _afterMint(to, amount);
    }

    /// @inheritdoc ISMART
    /// @dev Requires owner privileges.
    function batchMint(address[] calldata toList, uint256[] calldata amounts) external virtual override onlyOwner {
        if (toList.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < toList.length; i++) {
            _beforeMint(toList[i], amounts[i]);
            _mint(toList[i], amounts[i]);
            _afterMint(toList[i], amounts[i]);
        }
    }

    /// @inheritdoc ERC20
    /// @dev Overrides ERC20.transfer to include SMART validation and hooks.
    function transfer(address to, uint256 amount) public virtual override(ERC20, IERC20) returns (bool) {
        address sender = _msgSender();
        _beforeTransfer(sender, to, amount, false);
        super._transfer(sender, to, amount);
        _afterTransfer(sender, to, amount);
        return true;
    }

    /// @inheritdoc ISMART
    function batchTransfer(address[] calldata toList, uint256[] calldata amounts) external virtual override {
        if (toList.length != amounts.length) revert LengthMismatch();
        address sender = _msgSender(); // Cache sender for efficiency
        for (uint256 i = 0; i < toList.length; i++) {
            // Use internal functions for consistency and to ensure hooks are called
            _beforeTransfer(sender, toList[i], amounts[i], false);
            super._transfer(sender, toList[i], amounts[i]); // Call ERC20's internal transfer
            _afterTransfer(sender, toList[i], amounts[i]);
        }
    }

    /// @inheritdoc ERC20
    /// @dev Overrides ERC20.transferFrom to include SMART validation and hooks.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        virtual
        override(ERC20, IERC20)
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
    function addComplianceModule(address module, bytes calldata params) external virtual override onlyOwner {
        _addComplianceModule(module, params);
    }

    /// @inheritdoc ISMART
    function removeComplianceModule(address module) external virtual override onlyOwner {
        _removeComplianceModule(module);
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
        _setParametersForComplianceModule(module, params);
    }

    // --- View Functions ---

    /// @inheritdoc ERC20
    function name() public view virtual override(ERC20, IERC20Metadata, _SMARTLogic) returns (string memory) {
        return __name; // Use state variable from _SMARTLogic
    }

    /// @inheritdoc ERC20
    function symbol() public view virtual override(ERC20, IERC20Metadata, _SMARTLogic) returns (string memory) {
        return __symbol; // Use state variable from _SMARTLogic
    }

    /// @inheritdoc ERC20
    function decimals() public view virtual override(ERC20, IERC20Metadata, _SMARTLogic) returns (uint8) {
        return __decimals; // Use state variable from _SMARTLogic
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
}
