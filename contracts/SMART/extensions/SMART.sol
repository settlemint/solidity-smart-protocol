// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISMART } from "../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../interface/ISMARTIdentityRegistry.sol";
import { ISMARTCompliance } from "../interface/ISMARTCompliance.sol";
import { ISMARTComplianceModule } from "../interface/ISMARTComplianceModule.sol";
import { SMARTHooks } from "./SMARTHooks.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { LengthMismatch } from "./common/CommonErrors.sol";

/// @title SMART
/// @notice Base extension that implements the core SMART token functionality
abstract contract SMART is SMARTHooks, ISMART, Ownable {
    // --- Custom Errors ---
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
    uint8 private immutable _decimals;
    address private _onchainID;
    ISMARTIdentityRegistry private _identityRegistry;
    ISMARTCompliance private _compliance;
    mapping(address => uint256) private _moduleIndex; // Store index + 1 for existence check
    mapping(address => bytes) private _moduleParameters; // Store parameters per module
    address[] private _complianceModuleList;
    uint256[] internal _requiredClaimTopics;

    // --- Events ---
    event TransferCompleted(address indexed from, address indexed to, uint256 amount);
    event MintValidated(address indexed to, uint256 amount);
    event MintCompleted(address indexed to, uint256 amount);
    // Note: UpdatedTokenInformation, IdentityRegistryAdded, ComplianceAdded,
    // ComplianceModuleAdded, ComplianceModuleRemoved are emitted but defined elsewhere (likely interfaces/base
    // contracts)

    // --- Constructor ---
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address onchainID_,
        address identityRegistry_,
        address compliance_,
        uint256[] memory requiredClaimTopics_,
        ComplianceModuleParamPair[] memory initialModulePairs_
    )
        ERC20(name_, symbol_)
    {
        if (compliance_ == address(0)) revert InvalidComplianceAddress();
        if (identityRegistry_ == address(0)) revert InvalidIdentityRegistryAddress();

        _decimals = decimals_;
        _onchainID = onchainID_;
        _identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        _compliance = ISMARTCompliance(compliance_);
        _requiredClaimTopics = requiredClaimTopics_;

        // Register initial modules and their parameters
        for (uint256 i = 0; i < initialModulePairs_.length; i++) {
            address module = initialModulePairs_[i].module;
            bytes memory params = initialModulePairs_[i].params;

            // Validate module and parameters internally (reverts on failure)
            _validateModuleAndParams(module, params);

            // Check for duplicates during initialization
            if (_moduleIndex[module] != 0) revert ModuleAlreadyAddedOnInit();

            // Add module and store parameters
            _complianceModuleList.push(module);
            _moduleIndex[module] = _complianceModuleList.length; // Store index + 1
            _moduleParameters[module] = params; // Store parameters

            emit ComplianceModuleAdded(module, params); // Emit with parameters
        }
    }

    // --- State-Changing Functions ---
    /// @inheritdoc ISMART
    function setName(string calldata _name) external virtual override onlyOwner {
        _setName(_name);
    }

    /// @inheritdoc ISMART
    function setSymbol(string calldata _symbol) external virtual override onlyOwner {
        _setSymbol(_symbol);
    }

    /// @inheritdoc ISMART
    function setOnchainID(address onchainID_) external virtual override onlyOwner {
        _onchainID = onchainID_;
        emit UpdatedTokenInformation(name(), symbol(), decimals(), _onchainID);
    }

    /// @inheritdoc ISMART
    function setIdentityRegistry(address identityRegistry_) external virtual override onlyOwner {
        if (identityRegistry_ == address(0)) revert InvalidIdentityRegistryAddress();
        _identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        emit IdentityRegistryAdded(address(_identityRegistry));
    }

    /// @inheritdoc ISMART
    function setCompliance(address compliance_) external virtual override onlyOwner {
        if (compliance_ == address(0)) revert InvalidComplianceAddress();
        _compliance = ISMARTCompliance(compliance_);
        emit ComplianceAdded(address(_compliance));
    }

    /// @inheritdoc ISMART
    function mint(address _to, uint256 _amount) external virtual override onlyOwner {
        _validateMint(_to, _amount);
        _mint(_to, _amount);
        _afterMint(_to, _amount);
    }

    /// @inheritdoc ISMART
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external virtual override onlyOwner {
        if (_toList.length != _amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < _toList.length; i++) {
            _validateMint(_toList[i], _amounts[i]);
            _mint(_toList[i], _amounts[i]);
            _afterMint(_toList[i], _amounts[i]);
        }
    }

    /// @inheritdoc ERC20
    function transfer(address to, uint256 amount) public virtual override(ERC20, IERC20) returns (bool) {
        address sender = msg.sender;
        _validateTransfer(sender, to, amount);
        _transfer(sender, to, amount);
        _afterTransfer(sender, to, amount);
        return true;
    }

    /// @inheritdoc ISMART
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external virtual override {
        if (_toList.length != _amounts.length) revert LengthMismatch();
        address sender = msg.sender;
        for (uint256 i = 0; i < _toList.length; i++) {
            _validateTransfer(sender, _toList[i], _amounts[i]);
            _transfer(sender, _toList[i], _amounts[i]);
            _afterTransfer(sender, _toList[i], _amounts[i]);
        }
    }

    /// @inheritdoc ERC20
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
        address spender = msg.sender;
        _validateTransfer(from, to, amount);
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        _afterTransfer(from, to, amount);
        return true;
    }

    /// @inheritdoc ISMART
    function addComplianceModule(address _module, bytes calldata _params) external virtual override onlyOwner {
        _validateModuleAndParams(_module, _params);

        if (_moduleIndex[_module] != 0) revert ModuleAlreadyAdded();

        _complianceModuleList.push(_module);
        _moduleIndex[_module] = _complianceModuleList.length;
        _moduleParameters[_module] = _params;

        emit ComplianceModuleAdded(_module, _params);
    }

    /// @inheritdoc ISMART
    function removeComplianceModule(address _module) external virtual override onlyOwner {
        uint256 index = _moduleIndex[_module];
        if (index == 0) revert ModuleNotFound();

        uint256 listIndex = index - 1;
        uint256 lastIndex = _complianceModuleList.length - 1;
        if (listIndex != lastIndex) {
            address lastModule = _complianceModuleList[lastIndex];
            _complianceModuleList[listIndex] = lastModule;
            _moduleIndex[lastModule] = listIndex + 1;
        }
        _complianceModuleList.pop();
        delete _moduleIndex[_module];
        delete _moduleParameters[_module];

        emit ComplianceModuleRemoved(_module);
    }

    /// @inheritdoc ISMART
    function setParametersForComplianceModule(
        address _module,
        bytes calldata _params
    )
        external
        virtual
        override
        onlyOwner
    {
        if (_moduleIndex[_module] == 0) revert ModuleNotFound();

        _validateModuleAndParams(_module, _params);

        _moduleParameters[_module] = _params;

        emit ModuleParametersUpdated(_module, _params);
    }

    // --- View Functions ---
    /// @inheritdoc ERC20
    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc ISMART
    function onchainID() external view virtual override returns (address) {
        return _onchainID;
    }

    /// @inheritdoc ISMART
    function identityRegistry() external view virtual override returns (ISMARTIdentityRegistry) {
        return _identityRegistry;
    }

    /// @inheritdoc ISMART
    function compliance() external view virtual override returns (ISMARTCompliance) {
        return _compliance;
    }

    /// @inheritdoc ISMART
    function requiredClaimTopics() external view virtual override returns (uint256[] memory) {
        return _requiredClaimTopics;
    }

    /// @inheritdoc ISMART
    function complianceModules() external view virtual override returns (ComplianceModuleParamPair[] memory) {
        uint256 length = _complianceModuleList.length;
        ComplianceModuleParamPair[] memory pairs = new ComplianceModuleParamPair[](length);

        for (uint256 i = 0; i < length; i++) {
            address module = _complianceModuleList[i];
            pairs[i] = ComplianceModuleParamPair({ module: module, params: _moduleParameters[module] });
        }

        return pairs;
    }

    /// @inheritdoc ISMART
    function getParametersForComplianceModule(address _module) external view virtual override returns (bytes memory) {
        return _moduleParameters[_module];
    }

    /// @inheritdoc ISMART
    function isValidComplianceModule(address _module, bytes calldata _params) external view virtual override {
        // Reverts internally if validation fails
        // Pass params as memory because internal function expects memory
        _validateModuleAndParams(_module, _params);
    }

    /// @inheritdoc ISMART
    function areValidComplianceModules(ComplianceModuleParamPair[] calldata _pairs) external view virtual override {
        for (uint256 i = 0; i < _pairs.length; i++) {
            // Reverts internally if validation fails for any module/param pair
            // Pass params as memory because internal function expects memory
            _validateModuleAndParams(_pairs[i].module, _pairs[i].params);
        }
    }

    // --- Internal Functions ---
    /// @dev Internal function to validate a module's interface support AND its parameters.
    ///      Reverts with appropriate error if validation fails.
    function _validateModuleAndParams(address _module, bytes memory _params) internal view {
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

    /// @inheritdoc SMARTHooks
    function _validateMint(address _to, uint256 _amount) internal virtual override {
        super._validateMint(_to, _amount);
        if (!_identityRegistry.isVerified(_to, _requiredClaimTopics)) revert RecipientNotVerified();
        if (!_compliance.canTransfer(address(this), address(0), _to, _amount)) revert MintNotCompliant();
        emit MintValidated(_to, _amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterMint(address _to, uint256 _amount) internal virtual override {
        super._afterMint(_to, _amount);
        _compliance.created(address(this), _to, _amount);
        emit MintCompleted(_to, _amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateTransfer(address _from, address _to, uint256 _amount) internal virtual override {
        super._validateTransfer(_from, _to, _amount);
        if (!_identityRegistry.isVerified(_to, _requiredClaimTopics)) revert RecipientNotVerified();
        if (!_compliance.canTransfer(address(this), _from, _to, _amount)) revert TransferNotCompliant();
    }

    /// @inheritdoc SMARTHooks
    function _afterTransfer(address _from, address _to, uint256 _amount) internal virtual override {
        super._afterTransfer(_from, _to, _amount);
        _compliance.transferred(address(this), _from, _to, _amount);
        emit TransferCompleted(_from, _to, _amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterBurn(address _from, uint256 _amount) internal virtual override {
        super._afterBurn(_from, _amount);
        _compliance.destroyed(address(this), _from, _amount);
    }

    /// @dev Internal function to set the token name
    function _setName(string memory _name) internal virtual {
        emit UpdatedTokenInformation(_name, symbol(), decimals(), _onchainID);
    }

    /// @dev Internal function to set the token symbol
    function _setSymbol(string memory _symbol) internal virtual {
        emit UpdatedTokenInformation(name(), _symbol, decimals(), _onchainID);
    }
}
