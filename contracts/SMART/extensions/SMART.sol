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

/// @title SMART
/// @notice Base extension that implements the core SMART token functionality
abstract contract SMART is SMARTHooks, ISMART {
    // --- Custom Errors ---
    error InvalidComplianceAddress();
    error InvalidIdentityRegistryAddress();
    error InvalidModuleAddress();
    error InvalidModuleImplementation();
    error ModuleAlreadyAddedOnInit();
    error LengthMismatch();
    error RecipientNotVerified();
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
    address[] private _complianceModuleList;
    uint256[] internal _requiredClaimTopics;

    // --- Events ---
    event TransferValidated(address indexed from, address indexed to, uint256 amount);
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
        address[] memory initialModules_
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

        // Register initial modules
        for (uint256 i = 0; i < initialModules_.length; i++) {
            address module = initialModules_[i];
            if (module == address(0)) revert InvalidModuleAddress();
            if (!_isValidModule(module)) revert InvalidModuleImplementation();
            if (_moduleIndex[module] != 0) revert ModuleAlreadyAddedOnInit();

            _complianceModuleList.push(module);
            _moduleIndex[module] = _complianceModuleList.length; // Store index + 1
            emit ComplianceModuleAdded(module);
        }
    }

    // --- State-Changing Functions ---
    /// @inheritdoc ISMART
    function setName(string calldata _name) external virtual override {
        _setName(_name);
    }

    /// @inheritdoc ISMART
    function setSymbol(string calldata _symbol) external virtual override {
        _setSymbol(_symbol);
    }

    /// @inheritdoc ISMART
    function setOnchainID(address onchainID_) external virtual override {
        _onchainID = onchainID_;
        emit UpdatedTokenInformation(name(), symbol(), decimals(), "1.0", _onchainID);
    }

    /// @inheritdoc ISMART
    function setIdentityRegistry(address identityRegistry_) external virtual override {
        if (identityRegistry_ == address(0)) revert InvalidIdentityRegistryAddress(); // Added check for consistency
        _identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        emit IdentityRegistryAdded(address(_identityRegistry));
    }

    /// @inheritdoc ISMART
    function setCompliance(address compliance_) external virtual override {
        if (compliance_ == address(0)) revert InvalidComplianceAddress(); // Added check for consistency
        _compliance = ISMARTCompliance(compliance_);
        emit ComplianceAdded(address(_compliance));
    }

    /// @inheritdoc ISMART
    function mint(address _to, uint256 _amount) external virtual override {
        _validateMint(_to, _amount);
        _mint(_to, _amount);
        _afterMint(_to, _amount);
    }

    /// @inheritdoc ISMART
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external virtual override {
        if (_toList.length != _amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < _toList.length; i++) {
            _validateMint(_toList[i], _amounts[i]);
            _mint(_toList[i], _amounts[i]);
            _afterMint(_toList[i], _amounts[i]);
        }
    }

    /// @inheritdoc ISMART
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external virtual override {
        if (_toList.length != _amounts.length) revert LengthMismatch();
        address sender = msg.sender; // Cache msg.sender
        for (uint256 i = 0; i < _toList.length; i++) {
            _validateTransfer(sender, _toList[i], _amounts[i]);
            _transfer(sender, _toList[i], _amounts[i]);
            _afterTransfer(sender, _toList[i], _amounts[i]);
        }
    }

    /// @inheritdoc ERC20
    function transfer(address to, uint256 amount) public virtual override(ERC20, IERC20) returns (bool) {
        address sender = msg.sender; // Cache msg.sender
        _validateTransfer(sender, to, amount);
        _transfer(sender, to, amount);
        _afterTransfer(sender, to, amount);
        return true;
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
        address spender = msg.sender; // Cache msg.sender
        _validateTransfer(from, to, amount);
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        _afterTransfer(from, to, amount);
        return true;
    }

    /// @inheritdoc ISMART
    function addComplianceModule(address _module) external virtual override {
        if (_module == address(0)) revert InvalidModuleAddress();
        if (!_isValidModule(_module)) revert InvalidModuleImplementation();
        if (_moduleIndex[_module] != 0) revert ModuleAlreadyAdded();

        _complianceModuleList.push(_module);
        _moduleIndex[_module] = _complianceModuleList.length; // Store index + 1
        emit ComplianceModuleAdded(_module);
    }

    /// @inheritdoc ISMART
    function removeComplianceModule(address _module) external virtual override {
        if (_module == address(0)) revert InvalidModuleAddress();
        uint256 index = _moduleIndex[_module];
        if (index == 0) revert ModuleNotFound();

        // Remove from array using swap and pop
        uint256 listIndex = index - 1;
        uint256 lastIndex = _complianceModuleList.length - 1;
        if (listIndex != lastIndex) {
            // Avoid self-assignment if removing the last element
            address lastModule = _complianceModuleList[lastIndex];
            _complianceModuleList[listIndex] = lastModule; // Swap with last element
            _moduleIndex[lastModule] = listIndex + 1; // Update index of moved module
        }
        _complianceModuleList.pop();
        delete _moduleIndex[_module]; // Remove from mapping

        emit ComplianceModuleRemoved(_module);
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
    function complianceModules() external view virtual override returns (address[] memory) {
        return _complianceModuleList;
    }

    /// @inheritdoc ISMART
    function isValidModule(address _module) external view virtual override returns (bool) {
        return _isValidModule(_module);
    }

    /// @inheritdoc ISMART
    function areValidModules(address[] calldata _modules) external view virtual override returns (bool) {
        for (uint256 i = 0; i < _modules.length; i++) {
            if (!_isValidModule(_modules[i])) {
                return false;
            }
        }
        return true;
    }

    // --- Internal Functions ---
    /// @inheritdoc SMARTHooks
    function _validateMint(address _to, uint256 _amount) internal virtual override {
        // Call base validation first
        super._validateMint(_to, _amount);

        // Then do SMART-specific validation
        if (!_identityRegistry.isVerified(_to, _requiredClaimTopics)) revert RecipientNotVerified();
        if (!_compliance.canTransfer(address(this), address(0), _to, _amount)) revert MintNotCompliant();
        emit MintValidated(_to, _amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterMint(address _to, uint256 _amount) internal virtual override {
        // Call base after-mint first
        super._afterMint(_to, _amount);

        // Then do SMART-specific after-mint
        _compliance.created(address(this), _to, _amount);
        emit MintCompleted(_to, _amount);
    }

    /// @inheritdoc SMARTHooks
    function _validateTransfer(address _from, address _to, uint256 _amount) internal virtual override {
        // Call base validation first
        super._validateTransfer(_from, _to, _amount);

        // Then do SMART-specific validation
        if (!_identityRegistry.isVerified(_to, _requiredClaimTopics)) revert RecipientNotVerified();
        if (!_compliance.canTransfer(address(this), _from, _to, _amount)) revert TransferNotCompliant();
        emit TransferValidated(_from, _to, _amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterTransfer(address _from, address _to, uint256 _amount) internal virtual override {
        // Call base after-transfer first
        super._afterTransfer(_from, _to, _amount);

        // Then do SMART-specific after-transfer
        _compliance.transferred(address(this), _from, _to, _amount);
        emit TransferCompleted(_from, _to, _amount);
    }

    /// @inheritdoc SMARTHooks
    function _afterBurn(address _from, uint256 _amount) internal virtual override {
        // Call base after-burn first
        super._afterBurn(_from, _amount);

        // Then do SMART-specific after-burn if needed (e.g., notify compliance if applicable)
        // Currently, ISMARTCompliance doesn't have a specific burn/redeem function to call here.
        // emit BurnCompleted(_from, _amount); // Optional: Define and emit a specific event if needed
    }

    /// @dev Internal function to set the token name
    function _setName(string memory _name) internal virtual {
        // Note: The original implementation did not update the state variable. Assuming intent was to emit only.
        // If the name should be updatable, the ERC20 internal _name variable needs to be handled appropriately,
        // which is not directly exposed. This might require overriding ERC20's name() and symbol() or a different
        // approach.
        // For now, preserving the original behavior of only emitting.
        emit UpdatedTokenInformation(_name, symbol(), decimals(), "1.0", _onchainID);
    }

    /// @dev Internal function to set the token symbol
    function _setSymbol(string memory _symbol) internal virtual {
        // Note: Similar to _setName, the original implementation did not update the state variable.
        // Preserving the original behavior of only emitting.
        emit UpdatedTokenInformation(name(), _symbol, decimals(), "1.0", _onchainID);
    }

    /// @dev Internal function to validate a module's interface support
    function _isValidModule(address _module) internal view returns (bool) {
        if (_module == address(0)) return false;

        try IERC165(_module).supportsInterface(type(ISMARTComplianceModule).interfaceId) returns (bool supported) {
            return supported;
        } catch {
            return false; // Catches revert or other errors during the interface check
        }
    }
}
