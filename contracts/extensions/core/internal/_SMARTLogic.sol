// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { ISMART } from "../../../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../../../interface/ISMARTIdentityRegistry.sol";
import { ISMARTCompliance } from "../../../interface/ISMARTCompliance.sol";
import { SMARTComplianceModuleParamPair } from "../../../interface/structs/SMARTComplianceModuleParamPair.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    DuplicateModule,
    MintNotCompliant,
    TransferNotCompliant,
    ModuleAlreadyAdded,
    ModuleNotFound,
    CannotRecoverSelf,
    InsufficientTokenBalance,
    InvalidDecimals
} from "../SMARTErrors.sol";
import { TokenRecovered } from "../SMARTEvents.sol";
import { _SMARTExtension } from "../../common/_SMARTExtension.sol";

// Error imports
import { LengthMismatch, ZeroAddressNotAllowed } from "../../common/CommonErrors.sol";
/// @title Internal Core Logic for SMART Tokens
/// @notice Base contract containing the core state, logic, events, and authorization hooks for SMART tokens.
/// @dev This abstract contract is intended to be inherited by both standard (SMART) and upgradeable (SMARTUpgradeable)
///      implementations. It defines shared state variables, internal logic, and hooks for extensibility.

abstract contract _SMARTLogic is _SMARTExtension {
    // -- Storage Variables --
    string internal __name; // Token name (mutable)
    string internal __symbol; // Token symbol (mutable)
    uint8 internal __decimals; // Token decimals
    address internal __onchainID; // Optional on-chain identifier address
    ISMARTIdentityRegistry internal __identityRegistry; // The identity registry contract
    ISMARTCompliance internal __compliance; // The compliance contract
    mapping(address => uint256) internal __moduleIndex; // Module address => index + 1 in __complianceModuleList (for
        // existence check)
    mapping(address => bytes) internal __moduleParameters; // Module address => associated parameters
    address[] internal __complianceModuleList; // List of active compliance module addresses
    uint256[] internal __requiredClaimTopics; // Claim topics required for verification

    // -- Abstract Functions (Dependencies) --

    /// @dev Abstract function representing the actual token burning mechanism.
    ///      Must be implemented by inheriting contracts to interact with the base token contract (e.g.,
    /// ERC20/ERC20Upgradeable).
    /// @param from The address from which tokens are burned.
    /// @param amount The amount of tokens to burn.
    function __smart_executeMint(address from, uint256 amount) internal virtual;

    /// @dev Abstract function representing the actual token transfer mechanism.
    ///      Must be implemented by inheriting contracts to interact with the base token contract (e.g.,
    /// ERC20/ERC20Upgradeable).
    /// @param from The address from which tokens are transferred.
    /// @param to The address to which tokens are transferred.
    /// @param amount The amount of tokens to transfer.
    function __smart_executeTransfer(address from, address to, uint256 amount) internal virtual;

    // -- Internal Implementation for ISMART Interface Functions --

    /// @dev Internal function to perform the mint operation after authorization.
    /// @param userAddress The address to mint tokens to.
    /// @param amount The amount of tokens to mint.
    function _smart_mint(address userAddress, uint256 amount) internal virtual {
        __smart_executeMint(userAddress, amount);
        emit MintCompleted(_smartSender(), userAddress, amount);
    }

    /// @dev Mints tokens to multiple addresses in a single transaction.
    ///      Requires authorization via `_authorizeMintToken` for each mint.
    ///      Includes compliance and verification checks via `_beforeMint` hook for each mint.
    /// @param toList The addresses to mint tokens to.
    /// @param amounts The amounts of tokens to mint.
    function _smart_batchMint(address[] calldata toList, uint256[] calldata amounts) internal virtual {
        if (toList.length != amounts.length) revert LengthMismatch();
        uint256 length = toList.length;
        for (uint256 i = 0; i < length; ++i) {
            _smart_mint(toList[i], amounts[i]);
        }
    }

    /// @dev Transfers tokens from the caller to a specified address.
    ///      Integrates SMART verification and compliance checks via hooks.
    function _smart_transfer(address to, uint256 amount) internal virtual returns (bool) {
        address sender = _smartSender();
        __smart_executeTransfer(sender, to, amount); // Execute the transfer// Calls _update ->
            // _beforeTransfer/_afterTransfer
        return true;
    }

    /// @dev Transfers tokens from the caller to multiple addresses in a single transaction.
    ///      Integrates SMART verification and compliance checks via hooks.
    /// @param toList The addresses to transfer tokens to.
    /// @param amounts The amounts of tokens to transfer.
    function _smart_batchTransfer(address[] calldata toList, uint256[] calldata amounts) internal virtual {
        if (toList.length != amounts.length) revert LengthMismatch();

        uint256 length = toList.length;
        for (uint256 i = 0; i < length; ++i) {
            _smart_transfer(toList[i], amounts[i]);
        }
    }

    /// @dev Internal function to set the token name.
    /// @param name_ The new token name.
    function _smart_setName(string memory name_) internal virtual {
        __name = name_;
        emit UpdatedTokenInformation(_smartSender(), __name, __symbol, __decimals, __onchainID);
    }

    /// @dev Internal function to set the token symbol.
    /// @param symbol_ The new token symbol.
    function _smart_setSymbol(string memory symbol_) internal virtual {
        __symbol = symbol_;
        emit UpdatedTokenInformation(_smartSender(), __name, __symbol, __decimals, __onchainID);
    }

    /// @dev Internal function to set the compliance contract.
    /// @param compliance_ The new compliance contract address.
    function _smart_setCompliance(address compliance_) internal virtual {
        if (compliance_ == address(0)) revert ZeroAddressNotAllowed();
        __compliance = ISMARTCompliance(compliance_);
        emit ComplianceAdded(_smartSender(), address(__compliance));
    }

    /// @dev Internal function to set the identity registry.
    /// @param identityRegistry_ The new identity registry address.
    function _smart_setIdentityRegistry(address identityRegistry_) internal virtual {
        if (identityRegistry_ == address(0)) revert ZeroAddressNotAllowed();
        __identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        emit IdentityRegistryAdded(_smartSender(), address(__identityRegistry));
    }

    /// @dev Internal function to set the on-chain ID.
    /// @param onchainID_ The new on-chain ID address.
    function _smart_setOnchainID(address onchainID_) internal virtual {
        __onchainID = onchainID_;
        emit UpdatedTokenInformation(_smartSender(), __name, __symbol, __decimals, __onchainID);
    }

    /// @dev Internal function to set the parameters for a compliance module.
    /// @param _module The address of the compliance module.
    /// @param _params The parameters to set for the compliance module.
    function _smart_setParametersForComplianceModule(address _module, bytes memory _params) internal virtual {
        if (__moduleIndex[_module] == 0) revert ModuleNotFound();
        __compliance.isValidComplianceModule(_module, _params);
        __moduleParameters[_module] = _params;
        emit ModuleParametersUpdated(_smartSender(), _module, _params);
    }

    /// @dev Internal function to add a compliance module.
    /// @param _module The address of the compliance module.
    /// @param _params The parameters to set for the compliance module.
    function _smart_addComplianceModule(address _module, bytes memory _params) internal virtual {
        __compliance.isValidComplianceModule(_module, _params);
        if (__moduleIndex[_module] != 0) revert ModuleAlreadyAdded();

        __complianceModuleList.push(_module);
        __moduleIndex[_module] = __complianceModuleList.length;
        __moduleParameters[_module] = _params;

        emit ComplianceModuleAdded(_smartSender(), _module, _params);
    }

    /// @dev Internal function to remove a compliance module.
    /// @param _module The address of the compliance module to remove.
    function _smart_removeComplianceModule(address _module) internal virtual {
        uint256 index = __moduleIndex[_module];
        if (index == 0) revert ModuleNotFound();

        // Efficiently remove from array by swapping with the last element
        uint256 listIndex = index - 1;
        uint256 lastIndex = __complianceModuleList.length - 1;
        if (listIndex != lastIndex) {
            address lastModule = __complianceModuleList[lastIndex];
            __complianceModuleList[listIndex] = lastModule;
            __moduleIndex[lastModule] = listIndex + 1; // Update index of the moved module
        }
        __complianceModuleList.pop();
        delete __moduleIndex[_module];
        delete __moduleParameters[_module];

        emit ComplianceModuleRemoved(_smartSender(), _module);
    }

    /// @dev Internal function to set the required claim topics.
    /// @param requiredClaimTopics_ The new required claim topics.
    function _smart_setRequiredClaimTopics(uint256[] memory requiredClaimTopics_) internal virtual {
        __requiredClaimTopics = requiredClaimTopics_;
        emit RequiredClaimTopicsUpdated(_smartSender(), __requiredClaimTopics);
    }

    /// @dev Internal function to recover ERC20 tokens.
    /// @param token The address of the ERC20 token to recover.
    /// @param to The recipient address for the recovered tokens.
    /// @param amount The amount of tokens to recover.
    function _smart_recoverERC20(address token, address to, uint256 amount) internal virtual {
        if (token == address(this)) revert CannotRecoverSelf();
        if (token == address(0)) revert ZeroAddressNotAllowed();
        if (to == address(0)) revert ZeroAddressNotAllowed();
        if (amount == 0) return;

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < amount) revert InsufficientTokenBalance();

        SafeERC20.safeTransfer(IERC20(token), to, amount);
        emit TokenRecovered(_smartSender(), token, to, amount);
    }

    // -- View Functions --

    /// @inheritdoc ISMART
    function onchainID() external view virtual override returns (address) {
        return __onchainID;
    }

    /// @inheritdoc ISMART
    function identityRegistry() external view virtual override returns (ISMARTIdentityRegistry) {
        return __identityRegistry;
    }

    /// @inheritdoc ISMART
    function compliance() external view virtual override returns (ISMARTCompliance) {
        return __compliance;
    }

    /// @inheritdoc ISMART
    function requiredClaimTopics() external view virtual override returns (uint256[] memory) {
        return __requiredClaimTopics;
    }

    /// @inheritdoc ISMART
    function complianceModules() external view virtual override returns (SMARTComplianceModuleParamPair[] memory) {
        uint256 length = __complianceModuleList.length;
        SMARTComplianceModuleParamPair[] memory pairs = new SMARTComplianceModuleParamPair[](length);

        for (uint256 i = 0; i < length; ++i) {
            address module = __complianceModuleList[i];
            pairs[i] = SMARTComplianceModuleParamPair({ module: module, params: __moduleParameters[module] });
        }

        return pairs;
    }

    // -- Internal Setup Function --

    /// @notice Internal function to initialize the core SMART state variables.
    /// @dev Called ONLY by the constructor (in standard SMART) or initializer (in SMARTUpgradeable).
    ///      Handles setting initial values and validating/registering initial compliance modules.
    /// @param name_ Token name.
    /// @param symbol_ Token symbol.
    /// @param decimals_ Token decimals.
    /// @param onchainID_ Optional on-chain identifier address.
    /// @param identityRegistry_ Address of the identity registry contract.
    /// @param compliance_ Address of the compliance contract.
    /// @param requiredClaimTopics_ Initial list of required claim topics for verification.
    /// @param initialModulePairs_ List of initial compliance modules and their parameters.
    function __SMART_init_unchained(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        SMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        internal
        virtual
    {
        if (compliance_ == address(0)) revert ZeroAddressNotAllowed();
        if (identityRegistry_ == address(0)) revert ZeroAddressNotAllowed();
        if (decimals_ > 18) revert InvalidDecimals(decimals_);

        __name = name_;
        __symbol = symbol_;
        __decimals = decimals_;
        __onchainID = onchainID_;
        __identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        __compliance = ISMARTCompliance(compliance_);
        __requiredClaimTopics = requiredClaimTopics_;

        __compliance.areValidComplianceModules(initialModulePairs_);

        address sender = _smartSender();

        // Register initial modules and their parameters
        for (uint256 i = 0; i < initialModulePairs_.length; i++) {
            address module = initialModulePairs_[i].module;
            bytes memory params = initialModulePairs_[i].params;

            if (__moduleIndex[module] != 0) revert DuplicateModule(module);

            __complianceModuleList.push(module);
            __moduleIndex[module] = __complianceModuleList.length; // Store index + 1
            __moduleParameters[module] = params;
            emit ComplianceModuleAdded(sender, module, params);
        }

        emit IdentityRegistryAdded(sender, identityRegistry_);
        emit ComplianceAdded(sender, compliance_);
        emit UpdatedTokenInformation(sender, name_, symbol_, decimals_, onchainID_);
        emit RequiredClaimTopicsUpdated(sender, requiredClaimTopics_);
    }

    // -- Internal Hook Helper Functions --

    /// @dev Internal logic executed before an update operation to check recipient verification and compliance.
    ///      This function is intended to be called by the `_beforeUpdate` hook in the inheriting contract.
    /// @param from The address that sent the tokens.
    /// @param to The address that received the tokens.
    /// @param amount The amount of tokens transferred.
    function __smart_beforeUpdateLogic(address from, address to, uint256 amount) internal virtual {
        if (!__isForcedUpdate) {
            if (!__identityRegistry.isVerified(to, __requiredClaimTopics)) revert RecipientNotVerified();
            if (!__compliance.canTransfer(address(this), address(0), to, amount)) revert MintNotCompliant();
        }

        address sender = _smartSender();
        _beforeUpdate(sender, from, to, amount);
    }

    /// @dev Internal logic executed after an update operation to update historical balances.
    ///      This function is intended to be called by the `_afterUpdate` hook in the inheriting contract.
    /// @param from The address that sent the tokens.
    /// @param to The address that received the tokens.
    /// @param amount The amount of tokens transferred.
    function __smart_afterUpdateLogic(address from, address to, uint256 amount) internal virtual {
        address sender = _smartSender();
        _afterUpdate(sender, from, to, amount);

        if (from == address(0)) {
            __compliance.created(address(this), to, amount);
        } else if (to == address(0)) {
            __compliance.destroyed(address(this), from, amount);
        } else {
            emit TransferCompleted(_smartSender(), from, to, amount);
            __compliance.transferred(address(this), from, to, amount);
        }
    }

    /// @dev Internal function to check if an interface is supported.
    /// @param interfaceId The interface ID to check.
    function __smart_supportsInterface(bytes4 interfaceId) internal view virtual returns (bool) {
        return _isInterfaceRegistered[interfaceId] || interfaceId == type(ISMART).interfaceId;
    }
}
