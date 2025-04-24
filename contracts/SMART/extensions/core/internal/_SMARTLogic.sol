// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "../../../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../../../interface/ISMARTIdentityRegistry.sol";
import { ISMARTCompliance } from "../../../interface/ISMARTCompliance.sol";
import { ISMARTComplianceModule } from "../../../interface/ISMARTComplianceModule.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { _SMARTAuthorizationHooks } from "./_SMARTAuthorizationHooks.sol";

/// @title _SMARTLogic
/// @notice Base contract containing the core state, logic, and events for SMART tokens.
/// @dev This contract is intended to be inherited by both standard and upgradeable SMART implementations.
///      It does not include constructors or initializers itself.
abstract contract _SMARTLogic is ISMART, _SMARTAuthorizationHooks {
    // --- Errors ---
    error InvalidComplianceAddress();
    error InvalidIdentityRegistryAddress();
    error InvalidModuleAddress();
    error InvalidModuleImplementation();
    error ModuleAlreadyAddedOnInit();
    error MintNotCompliant();
    error TransferNotCompliant();
    error ModuleAlreadyAdded();
    error ModuleNotFound();

    // --- Storage Variables ---
    string internal __name; // Store name mutable
    string internal __symbol; // Store symbol mutable
    uint8 internal __decimals; // Internal storage for decimals
    address internal __onchainID; // Internal storage for onchainID
    ISMARTIdentityRegistry internal __identityRegistry;
    ISMARTCompliance internal __compliance;
    mapping(address => uint256) internal __moduleIndex; // Store index + 1 for existence check
    mapping(address => bytes) internal __moduleParameters; // Store parameters per module
    address[] internal __complianceModuleList;
    uint256[] internal __requiredClaimTopics;

    // --- Events ---
    // Events defined in ISMART (e.g., UpdatedTokenInformation) are implicitly included and emitted by internal logic.
    event TransferCompleted(address indexed from, address indexed to, uint256 amount);
    event MintValidated(address indexed to, uint256 amount);
    event MintCompleted(address indexed to, uint256 amount);
    event RequiredClaimTopicsUpdated(uint256[] requiredClaimTopics); // Added event

    // --- View Functions ---

    function name() public view virtual override returns (string memory) {
        return __name;
    }

    function symbol() public view virtual override returns (string memory) {
        return __symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return __decimals;
    }

    function onchainID() external view virtual override returns (address) {
        return __onchainID;
    }

    function identityRegistry() external view virtual override returns (ISMARTIdentityRegistry) {
        return __identityRegistry;
    }

    function compliance() external view virtual override returns (ISMARTCompliance) {
        return __compliance;
    }

    function requiredClaimTopics() external view virtual override returns (uint256[] memory) {
        return __requiredClaimTopics;
    }

    function complianceModules() external view virtual override returns (ComplianceModuleParamPair[] memory) {
        uint256 length = __complianceModuleList.length;
        ComplianceModuleParamPair[] memory pairs = new ComplianceModuleParamPair[](length);

        for (uint256 i = 0; i < length; i++) {
            address module = __complianceModuleList[i];
            pairs[i] = ComplianceModuleParamPair({ module: module, params: __moduleParameters[module] });
        }

        return pairs;
    }

    function getParametersForComplianceModule(address _module) external view virtual override returns (bytes memory) {
        return __moduleParameters[_module];
    }

    function isValidComplianceModule(address _module, bytes calldata _params) external view virtual override {
        _validateModuleAndParams(_module, _params); // Calls internal shared logic
    }

    function areValidComplianceModules(ComplianceModuleParamPair[] calldata _pairs) external view virtual override {
        for (uint256 i = 0; i < _pairs.length; i++) {
            _validateModuleAndParams(_pairs[i].module, _pairs[i].params); // Calls internal shared logic
        }
    }

    // --- Internal Functions ---

    /// @dev Internal function to set up the core SMART state.
    ///      Called ONLY by the constructor (standard) or initializer (upgradeable).
    function __SMART_init_unchained(
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
        virtual
    {
        if (compliance_ == address(0)) revert InvalidComplianceAddress();
        if (identityRegistry_ == address(0)) revert InvalidIdentityRegistryAddress();

        __name = name_;
        __symbol = symbol_;
        __decimals = decimals_;
        __onchainID = onchainID_;
        __identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        __compliance = ISMARTCompliance(compliance_);
        __requiredClaimTopics = requiredClaimTopics_;

        // Register initial modules and their parameters
        for (uint256 i = 0; i < initialModulePairs_.length; i++) {
            address module = initialModulePairs_[i].module;
            bytes memory params = initialModulePairs_[i].params;

            // Validate module and parameters internally (reverts on failure)
            _validateModuleAndParams(module, params);

            // Check for duplicates during initialization
            if (__moduleIndex[module] != 0) revert ModuleAlreadyAddedOnInit();

            // Add module and store parameters
            __complianceModuleList.push(module);
            __moduleIndex[module] = __complianceModuleList.length; // Store index + 1
            __moduleParameters[module] = params;

            emit ComplianceModuleAdded(module, params);
        }

        emit IdentityRegistryAdded(identityRegistry_);
        emit ComplianceAdded(compliance_);
        emit UpdatedTokenInformation(name_, symbol_, decimals_, onchainID_);
        emit RequiredClaimTopicsUpdated(requiredClaimTopics_); // Emit initial topics
    }

    /// @dev Internal function to validate a module's interface support AND its parameters.
    ///      Reverts with appropriate error if validation fails.
    function _validateModuleAndParams(address _module, bytes memory _params) internal view virtual {
        if (_module == address(0)) revert InvalidModuleAddress();

        bool supportsInterface;
        try IERC165(_module).supportsInterface(type(ISMARTComplianceModule).interfaceId) returns (bool supported) {
            supportsInterface = supported;
        } catch {
            revert InvalidModuleImplementation();
        }
        if (!supportsInterface) {
            revert InvalidModuleImplementation();
        }

        ISMARTComplianceModule(_module).validateParameters(_params);
    }

    function _addComplianceModule(address _module, bytes memory _params) internal virtual {
        _authorizeUpdateComplianceSettings();
        _validateModuleAndParams(_module, _params);
        if (__moduleIndex[_module] != 0) revert ModuleAlreadyAdded();

        __complianceModuleList.push(_module);
        __moduleIndex[_module] = __complianceModuleList.length;
        __moduleParameters[_module] = _params;

        emit ComplianceModuleAdded(_module, _params);
    }

    function _removeComplianceModule(address _module) internal virtual {
        _authorizeUpdateComplianceSettings();
        uint256 index = __moduleIndex[_module];
        if (index == 0) revert ModuleNotFound();

        uint256 listIndex = index - 1;
        uint256 lastIndex = __complianceModuleList.length - 1;
        if (listIndex != lastIndex) {
            address lastModule = __complianceModuleList[lastIndex];
            __complianceModuleList[listIndex] = lastModule;
            __moduleIndex[lastModule] = listIndex + 1;
        }
        __complianceModuleList.pop();
        delete __moduleIndex[_module];
        delete __moduleParameters[_module];

        emit ComplianceModuleRemoved(_module);
    }

    function _setParametersForComplianceModule(address _module, bytes memory _params) internal virtual {
        _authorizeUpdateComplianceSettings();
        if (__moduleIndex[_module] == 0) revert ModuleNotFound();
        _validateModuleAndParams(_module, _params);
        __moduleParameters[_module] = _params;
        emit ModuleParametersUpdated(_module, _params);
    }

    function _setOnchainID(address onchainID_) internal virtual {
        _auhtorizeUpdateTokenSettings();
        __onchainID = onchainID_;
        emit UpdatedTokenInformation(__name, __symbol, __decimals, __onchainID);
    }

    function _setIdentityRegistry(address identityRegistry_) internal virtual {
        _authorizeUpdateVerificationSettings();
        if (identityRegistry_ == address(0)) revert InvalidIdentityRegistryAddress();
        __identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        emit IdentityRegistryAdded(address(__identityRegistry));
    }

    function _setCompliance(address compliance_) internal virtual {
        _authorizeUpdateComplianceSettings();
        if (compliance_ == address(0)) revert InvalidComplianceAddress();
        __compliance = ISMARTCompliance(compliance_);
        emit ComplianceAdded(address(__compliance));
    }

    function _setRequiredClaimTopics(uint256[] memory requiredClaimTopics_) internal virtual {
        _authorizeUpdateVerificationSettings();
        __requiredClaimTopics = requiredClaimTopics_;
        emit RequiredClaimTopicsUpdated(__requiredClaimTopics);
    }

    function _setName(string memory name_) internal virtual {
        _auhtorizeUpdateTokenSettings();
        __name = name_;
        emit UpdatedTokenInformation(__name, __symbol, __decimals, __onchainID);
    }

    function _setSymbol(string memory symbol_) internal virtual {
        _auhtorizeUpdateTokenSettings();
        __symbol = symbol_;
        emit UpdatedTokenInformation(__name, __symbol, __decimals, __onchainID);
    }

    // Helper Functions for Hooks
    function _smart_beforeMintLogic(address to, uint256 amount) internal virtual {
        _authorizeMintToken(); // TODO check if this is the right location for this check
        if (!__identityRegistry.isVerified(to, __requiredClaimTopics)) revert RecipientNotVerified();
        if (!__compliance.canTransfer(address(this), address(0), to, amount)) revert MintNotCompliant();
        emit MintValidated(to, amount);
    }

    function _smart_afterMintLogic(address to, uint256 amount) internal virtual {
        __compliance.created(address(this), to, amount);
        emit MintCompleted(to, amount);
    }

    function _smart_beforeTransferLogic(address from, address to, uint256 amount, bool) internal virtual {
        if (!__identityRegistry.isVerified(to, __requiredClaimTopics)) revert RecipientNotVerified();
        if (!__compliance.canTransfer(address(this), from, to, amount)) revert TransferNotCompliant();
    }

    function _smart_afterTransferLogic(address from, address to, uint256 amount) internal virtual {
        __compliance.transferred(address(this), from, to, amount);
        emit TransferCompleted(from, to, amount);
    }

    function _smart_afterBurnLogic(address from, uint256 amount) internal virtual {
        __compliance.destroyed(address(this), from, amount);
    }
}
