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
        // Call the internal initializer from the base logic contract
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
        // UpdatedTokenInformation is emitted within __SMART_init_unchained now
    }

    // --- State-Changing Functions ---
    // Override functions from ISMART (via _SMARTLogic) and ERC20/Ownable as needed

    /// @inheritdoc ISMART
    function setName(string calldata name_) external virtual override onlyOwner {
        _setName(name_); // Calls _SMARTLogic's internal _setName
            // Event is emitted within _setName
    }

    /// @inheritdoc ISMART
    function setSymbol(string calldata symbol_) external virtual override onlyOwner {
        _setSymbol(symbol_); // Calls _SMARTLogic's internal _setSymbol
            // Event is emitted within _setSymbol
    }

    /// @inheritdoc ISMART
    function setOnchainID(address onchainID_) external virtual override onlyOwner {
        _setOnchainID(onchainID_); // Call internal logic from base
            // Event is emitted within _setOnchainID
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
    function mint(address to, uint256 amount) external virtual override onlyOwner {
        _validateMint(to, amount); // Calls SMARTExtension -> _SMARTLogic validation
        _mint(to, amount); // Calls ERC20 _mint
        _afterMint(to, amount); // Calls SMARTExtension -> _SMARTLogic hooks
    }

    /// @inheritdoc ISMART
    function batchMint(address[] calldata toList, uint256[] calldata amounts) external virtual override onlyOwner {
        if (toList.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < toList.length; i++) {
            // Use internal implementations
            _validateMint(toList[i], amounts[i]);
            _mint(toList[i], amounts[i]); // Use ERC20 internal _mint
            _afterMint(toList[i], amounts[i]);
        }
    }

    /// @inheritdoc ERC20
    /// @dev Overrides ERC20.transfer to include SMART validation and hooks.
    function transfer(address to, uint256 amount) public virtual override(ERC20, IERC20) returns (bool) {
        address sender = _msgSender();
        _validateTransfer(sender, to, amount); // Calls SMARTExtension -> _SMARTLogic validation
        // _transfer is ERC20's internal function, calls _update
        super._transfer(sender, to, amount); // Call ERC20's _transfer
        _afterTransfer(sender, to, amount); // Calls SMARTExtension -> _SMARTLogic hooks
        return true;
    }

    /// @inheritdoc ISMART
    function batchTransfer(address[] calldata toList, uint256[] calldata amounts) external virtual override {
        if (toList.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < toList.length; i++) {
            // Use public transfer function for each transfer
            transfer(toList[i], amounts[i]);
            // // Alternative: Direct internal calls (requires sender context)
            // _validateTransfer(sender, toList[i], amounts[i]);
            // super._transfer(sender, toList[i], amounts[i]); // Call ERC20's internal transfer
            // _afterTransfer(sender, toList[i], amounts[i]);
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
        // Validation should happen before allowance check for security/compliance
        _validateTransfer(from, to, amount); // Calls SMARTExtension -> _SMARTLogic validation
        // _spendAllowance is ERC20's internal function
        super._spendAllowance(from, spender, amount);
        // _transfer is ERC20's internal function
        super._transfer(from, to, amount); // Call ERC20's _transfer
        _afterTransfer(from, to, amount); // Calls SMARTExtension -> _SMARTLogic hooks
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
    // Override ERC20 views to use _SMARTLogic state

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

    // --- Internal Functions ---
    // Internal hooks (_validate*, _after*) inherit SMARTExtension and call _SMARTLogic via super.

    /// @inheritdoc SMARTHooks
    function _validateMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        // Call logic helper from _SMARTLogic with new name
        _smart_validateMintLogic(to, amount);
        super._validateMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterMint(address to, uint256 amount) internal virtual override(SMARTHooks) {
        // Call logic helper from _SMARTLogic with new name
        _smart_afterMintLogic(to, amount);
        super._afterMint(to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        // Call logic helper from _SMARTLogic with new name
        _smart_validateTransferLogic(from, to, amount);
        super._validateTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterTransfer(address from, address to, uint256 amount) internal virtual override(SMARTHooks) {
        // Call logic helper from _SMARTLogic with new name
        _smart_afterTransferLogic(from, to, amount);
        super._afterTransfer(from, to, amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterBurn(address from, uint256 amount) internal virtual override(SMARTHooks) {
        // Call logic helper from _SMARTLogic with new name
        _smart_afterBurnLogic(from, amount);
        super._afterBurn(from, amount);
    }

    // --- Overrides for ERC20 name/symbol setters to emit UpdatedTokenInformation ---
    // REMOVED internal _setName and _setSymbol overrides as they don't exist in ERC20 base

    // Removed _validateModuleAndParams - logic moved to _SMARTLogic
}
