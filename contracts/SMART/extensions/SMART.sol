// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISMART } from "../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../interface/ISMARTIdentityRegistry.sol";
import { ISMARTCompliance } from "../interface/ISMARTCompliance.sol";
import { ISMARTComplianceModule } from "../interface/ISMARTComplianceModule.sol";
import { SMARTHooks } from "./SMARTHooks.sol";

/// @title SMART
/// @notice Base extension that implements the core SMART token functionality
abstract contract SMART is SMARTHooks, ISMART {
    /// Storage
    address private _onchainID;
    ISMARTIdentityRegistry private _identityRegistry;
    ISMARTCompliance private _compliance;
    mapping(address => bool) private _registeredModules;
    uint256[] private _requiredClaimTopics;

    /// Events
    event TransferValidated(address indexed from, address indexed to, uint256 amount);
    event TransferCompleted(address indexed from, address indexed to, uint256 amount);
    event MintValidated(address indexed to, uint256 amount);
    event MintCompleted(address indexed to, uint256 amount);

    /// Constructor
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
        require(compliance_ != address(0), "Invalid compliance address");
        require(identityRegistry_ != address(0), "Invalid identity registry address");

        _onchainID = onchainID_;
        _identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        _compliance = ISMARTCompliance(compliance_);
        _requiredClaimTopics = requiredClaimTopics_;

        // Register initial modules
        for (uint256 i = 0; i < initialModules_.length; i++) {
            require(initialModules_[i] != address(0), "Invalid module address");
            require(_isValidModule(initialModules_[i]), "Invalid module implementation");
            _registeredModules[initialModules_[i]] = true;
            emit ComplianceModuleAdded(initialModules_[i]);
        }
    }

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
        _identityRegistry = ISMARTIdentityRegistry(identityRegistry_);
        emit IdentityRegistryAdded(address(_identityRegistry));
    }

    /// @inheritdoc ISMART
    function setCompliance(address compliance_) external virtual override {
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
        require(_toList.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _toList.length; i++) {
            _validateMint(_toList[i], _amounts[i]);
            _mint(_toList[i], _amounts[i]);
            _afterMint(_toList[i], _amounts[i]);
        }
    }

    /// @inheritdoc ISMART
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external virtual override {
        require(_toList.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _toList.length; i++) {
            _validateTransfer(msg.sender, _toList[i], _amounts[i]);
            _transfer(msg.sender, _toList[i], _amounts[i]);
            _afterTransfer(msg.sender, _toList[i], _amounts[i]);
        }
    }

    function transfer(address to, uint256 amount) public virtual override(ERC20, IERC20) returns (bool) {
        _validateTransfer(msg.sender, to, amount);
        _transfer(msg.sender, to, amount);
        _afterTransfer(msg.sender, to, amount);
        return true;
    }

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
        _validateTransfer(from, to, amount);
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        _afterTransfer(from, to, amount);
        return true;
    }

    /// @inheritdoc SMARTHooks
    function _validateMint(address _to, uint256 _amount) internal virtual override {
        // Call base validation first
        super._validateMint(_to, _amount);

        // Then do SMART-specific validation
        require(_identityRegistry.isVerified(_to, _requiredClaimTopics), "Recipient not verified");
        require(_compliance.canTransfer(address(this), address(0), _to, _amount), "Mint not compliant");
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
        require(_identityRegistry.isVerified(_to, _requiredClaimTopics), "Recipient not verified");
        require(_compliance.canTransfer(address(this), _from, _to, _amount), "Transfer not compliant");
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
        // Return empty array as placeholder since getModules() is not available
        return new address[](0);
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

    /// @inheritdoc ISMART
    function addComplianceModule(address _module) external virtual override {
        require(_module != address(0), "Invalid module address");
        require(_isValidModule(_module), "Invalid module implementation");
        require(!_registeredModules[_module], "Module already added");

        _registeredModules[_module] = true;
        emit ComplianceModuleAdded(_module);
    }

    /// @inheritdoc ISMART
    function removeComplianceModule(address _module) external virtual override {
        require(_module != address(0), "Invalid module address");
        require(_registeredModules[_module], "Module not found");

        _registeredModules[_module] = false;
        emit ComplianceModuleRemoved(_module);
    }

    /// Internal functions
    function _setName(string memory _name) internal virtual {
        _name = _name;
        emit UpdatedTokenInformation(_name, symbol(), decimals(), "1.0", _onchainID);
    }

    function _setSymbol(string memory _symbol) internal virtual {
        _symbol = _symbol;
        emit UpdatedTokenInformation(name(), _symbol, decimals(), "1.0", _onchainID);
    }

    /// @dev Internal function to validate a module
    function _isValidModule(address _module) internal view returns (bool) {
        if (_module == address(0)) return false;

        try ISMARTComplianceModule(_module).moduleCheck(address(0), address(0), address(0), 0) {
            try ISMARTComplianceModule(_module).moduleTransferAction(address(0), address(0), address(0), 0) {
                try ISMARTComplianceModule(_module).moduleMintAction(address(0), address(0), 0) {
                    try ISMARTComplianceModule(_module).moduleBurnAction(address(0), address(0), 0) {
                        return true;
                    } catch {
                        return false;
                    }
                } catch {
                    return false;
                }
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }
}
