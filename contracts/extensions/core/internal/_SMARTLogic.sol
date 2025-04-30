// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../../../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../../../interface/ISMARTIdentityRegistry.sol";
import { ISMARTCompliance } from "../../../interface/ISMARTCompliance.sol";
import { ISMARTComplianceModuleParamPair } from "../../../interface/structs/ISMARTComplianceModuleParamPair.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { _SMARTAuthorizationHooks } from "./_SMARTAuthorizationHooks.sol";
import { ZeroAddressNotAllowed } from "../../common/CommonErrors.sol";
import {
    DuplicateModule,
    MintNotCompliant,
    TransferNotCompliant,
    ModuleAlreadyAdded,
    ModuleNotFound,
    CannotRecoverSelf,
    InsufficientTokenBalance
} from "../SMARTErrors.sol";
import { TokenRecovered } from "../SMARTEvents.sol";
/// @title Internal Core Logic for SMART Tokens
/// @notice Base contract containing the core state, logic, events, and authorization hooks for SMART tokens.
/// @dev This abstract contract is intended to be inherited by both standard (SMART) and upgradeable (SMARTUpgradeable)
///      implementations. It defines shared state variables, internal logic, and hooks for extensibility.

abstract contract _SMARTLogic is ISMART, _SMARTAuthorizationHooks {
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

    // -- State-Changing Functions (Admin/Authorized) --

    /// @inheritdoc ISMART
    /// @dev Requires authorization via `_authorizeUpdateTokenSettings`.
    function setName(string memory name_) external virtual override {
        _authorizeUpdateTokenSettings();
        __name = name_;
        emit UpdatedTokenInformation(__name, __symbol, __decimals, __onchainID);
    }

    /// @inheritdoc ISMART
    /// @dev Requires authorization via `_authorizeUpdateTokenSettings`.
    function setSymbol(string memory symbol_) external virtual override {
        _authorizeUpdateTokenSettings();
        __symbol = symbol_;
        emit UpdatedTokenInformation(__name, __symbol, __decimals, __onchainID);
    }

    /// @inheritdoc ISMART
    /// @dev Requires authorization via `_authorizeUpdateComplianceSettings`.
    function setCompliance(address compliance_) external virtual override {
        _authorizeUpdateComplianceSettings();
        if (compliance_ == address(0)) revert ZeroAddressNotAllowed();
        __compliance = ISMARTCompliance(compliance_);
        emit ComplianceAdded(address(__compliance));
    }

    /// @inheritdoc ISMART
    /// @dev Requires authorization via `_authorizeUpdateVerificationSettings`.
    function setIdentityRegistry(address identityRegistry_) external virtual override {
        _authorizeUpdateVerificationSettings();
        if (identityRegistry_ == address(0)) revert ZeroAddressNotAllowed();
        __identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        emit IdentityRegistryAdded(address(__identityRegistry));
    }

    /// @inheritdoc ISMART
    /// @dev Requires authorization via `_authorizeUpdateTokenSettings`.
    function setOnchainID(address onchainID_) external virtual override {
        _authorizeUpdateTokenSettings();
        __onchainID = onchainID_;
        emit UpdatedTokenInformation(__name, __symbol, __decimals, __onchainID);
    }

    /// @inheritdoc ISMART
    /// @dev Requires authorization via `_authorizeUpdateComplianceSettings`.
    function setParametersForComplianceModule(address _module, bytes memory _params) external virtual override {
        _authorizeUpdateComplianceSettings();
        if (__moduleIndex[_module] == 0) revert ModuleNotFound();
        __compliance.isValidComplianceModule(_module, _params);
        __moduleParameters[_module] = _params;
        emit ModuleParametersUpdated(_module, _params);
    }

    /// @inheritdoc ISMART
    /// @dev Requires authorization via `_authorizeUpdateComplianceSettings`.
    function addComplianceModule(address _module, bytes memory _params) external virtual override {
        _authorizeUpdateComplianceSettings();
        __compliance.isValidComplianceModule(_module, _params);
        if (__moduleIndex[_module] != 0) revert ModuleAlreadyAdded();

        __complianceModuleList.push(_module);
        __moduleIndex[_module] = __complianceModuleList.length;
        __moduleParameters[_module] = _params;

        emit ComplianceModuleAdded(_module, _params);
    }

    /// @inheritdoc ISMART
    /// @dev Requires authorization via `_authorizeUpdateComplianceSettings`.
    function removeComplianceModule(address _module) external virtual override {
        _authorizeUpdateComplianceSettings();
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

        emit ComplianceModuleRemoved(_module);
    }

    /// @inheritdoc ISMART
    /// @dev Requires authorization via `_authorizeUpdateVerificationSettings`.
    function setRequiredClaimTopics(uint256[] memory requiredClaimTopics_) external virtual override {
        _authorizeUpdateVerificationSettings();
        __requiredClaimTopics = requiredClaimTopics_;
        emit RequiredClaimTopicsUpdated(__requiredClaimTopics);
    }

    /// @notice Recovers mistakenly sent ERC20 tokens from this contract's address.
    /// @dev Requires authorization via `_authorizeRecoverERC20`. Cannot recover this contract's own token.
    ///      Uses SafeERC20's safeTransfer.
    /// @param token The address of the ERC20 token to recover.
    /// @param to The recipient address for the recovered tokens.
    /// @param amount The amount of tokens to recover.
    function recoverERC20(address token, address to, uint256 amount) external virtual {
        _authorizeRecoverERC20(); // Authorization check

        if (token == address(this)) revert CannotRecoverSelf();
        if (token == address(0)) revert ZeroAddressNotAllowed();
        if (to == address(0)) revert ZeroAddressNotAllowed();
        if (amount == 0) return;

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < amount) revert InsufficientTokenBalance();

        SafeERC20.safeTransfer(IERC20(token), to, amount);
        emit TokenRecovered(token, to, amount);
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
    function complianceModules() external view virtual override returns (ISMARTComplianceModuleParamPair[] memory) {
        uint256 length = __complianceModuleList.length;
        ISMARTComplianceModuleParamPair[] memory pairs = new ISMARTComplianceModuleParamPair[](length);

        for (uint256 i = 0; i < length; i++) {
            address module = __complianceModuleList[i];
            pairs[i] = ISMARTComplianceModuleParamPair({ module: module, params: __moduleParameters[module] });
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
        ISMARTComplianceModuleParamPair[] memory initialModulePairs_
    )
        internal
        virtual
    {
        if (compliance_ == address(0)) revert ZeroAddressNotAllowed();
        if (identityRegistry_ == address(0)) revert ZeroAddressNotAllowed();

        __name = name_;
        __symbol = symbol_;
        __decimals = decimals_;
        __onchainID = onchainID_;
        __identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        __compliance = ISMARTCompliance(compliance_);
        __requiredClaimTopics = requiredClaimTopics_;

        __compliance.areValidComplianceModules(initialModulePairs_);

        // Register initial modules and their parameters
        for (uint256 i = 0; i < initialModulePairs_.length; i++) {
            address module = initialModulePairs_[i].module;
            bytes memory params = initialModulePairs_[i].params;

            if (__moduleIndex[module] != 0) revert DuplicateModule(module);

            __complianceModuleList.push(module);
            __moduleIndex[module] = __complianceModuleList.length; // Store index + 1
            __moduleParameters[module] = params;
            emit ComplianceModuleAdded(module, params);
        }

        emit IdentityRegistryAdded(identityRegistry_);
        emit ComplianceAdded(compliance_);
        emit UpdatedTokenInformation(name_, symbol_, decimals_, onchainID_);
        emit RequiredClaimTopicsUpdated(requiredClaimTopics_);
    }

    // -- Internal Hook Helper Functions --

    /// @notice Internal logic executed before a mint operation.
    /// @dev Performs mint authorization check, recipient verification, and compliance checks.
    ///      Called by the implementing contract's `_beforeMint` hook.
    /// @param to The recipient address.
    /// @param amount The amount being minted.
    function _smart_beforeMintLogic(address to, uint256 amount) internal virtual {
        _authorizeMintToken(); // Check if caller is authorized to mint
        if (!__identityRegistry.isVerified(to, __requiredClaimTopics)) revert RecipientNotVerified();
        if (!__compliance.canTransfer(address(this), address(0), to, amount)) revert MintNotCompliant();
    }

    /// @notice Internal logic executed after a mint operation.
    /// @dev Notifies the compliance contract and emits the MintCompleted event.
    ///      Called by the implementing contract's `_afterMint` hook.
    /// @param to The recipient address.
    /// @param amount The amount that was minted.
    function _smart_afterMintLogic(address to, uint256 amount) internal virtual {
        emit MintCompleted(to, amount);
        __compliance.created(address(this), to, amount);
    }

    /// @notice Internal logic executed before a transfer operation (transfer, transferFrom).
    /// @dev Performs recipient verification and compliance checks.
    ///      Called by the implementing contract's `_beforeTransfer` hook.
    /// @param from The sender address.
    /// @param to The recipient address.
    /// @param amount The amount being transferred.
    function _smart_beforeTransferLogic(address from, address to, uint256 amount) internal virtual {
        // Note: Sender verification is implicitly handled by ERC20 balance/allowance checks.
        if (!__identityRegistry.isVerified(to, __requiredClaimTopics)) revert RecipientNotVerified();
        if (!__compliance.canTransfer(address(this), from, to, amount)) revert TransferNotCompliant();
    }

    /// @notice Internal logic executed after a transfer operation.
    /// @dev Notifies the compliance contract and emits the TransferCompleted event.
    ///      Called by the implementing contract's `_afterTransfer` hook.
    /// @param from The sender address.
    /// @param to The recipient address.
    /// @param amount The amount that was transferred.
    function _smart_afterTransferLogic(address from, address to, uint256 amount) internal virtual {
        emit TransferCompleted(from, to, amount);
        __compliance.transferred(address(this), from, to, amount);
    }

    /// @notice Internal logic executed after a burn operation.
    /// @dev Notifies the compliance contract about the destroyed tokens.
    ///      Called by the implementing contract's `_afterBurn` hook.
    /// @param from The address from which tokens were burned.
    /// @param amount The amount that was burned.
    function _smart_afterBurnLogic(address from, uint256 amount) internal virtual {
        __compliance.destroyed(address(this), from, amount);
    }
}
