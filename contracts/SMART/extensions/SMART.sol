// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ISMART } from "../interface/ISMART.sol";
import { ISMARTIdentityRegistry } from "../interface/ISmartIdentityRegistry.sol";
import { ISMARTCompliance } from "../interface/ISmartCompliance.sol";
import { ISMARTComplianceModule } from "../interface/ISMARTComplianceModule.sol";

/// @title SMART
/// @notice Base extension that implements the core SMART token functionality
abstract contract SMART is ERC20, ISMART {
    /// Storage
    address private _onchainID;
    ISMARTIdentityRegistry private _identityRegistry;
    ISMARTCompliance private _compliance;
    mapping(address => bool) private _registeredModules;
    uint256[] private _requiredClaimTopics;

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
        emit IdentityRegistryAdded(_identityRegistry);
    }

    /// @inheritdoc ISMART
    function setCompliance(address compliance_) external virtual override {
        _compliance = ISMARTCompliance(compliance_);
        emit ComplianceAdded(_compliance);
    }

    /// @inheritdoc ISMART
    function mint(address _to, uint256 _amount) external virtual override {
        _mint(_to, _amount);
        _compliance.created(address(this), _to, _amount);
    }

    /// @inheritdoc ISMART
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external virtual override {
        require(_toList.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _toList.length; i++) {
            _mint(_toList[i], _amounts[i]);
            _compliance.created(address(this), _toList[i], _amounts[i]);
        }
    }

    /// @inheritdoc ISMART
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external virtual override {
        require(_toList.length == _amounts.length, "Length mismatch");
        for (uint256 i = 0; i < _toList.length; i++) {
            transfer(_toList[i], _amounts[i]);
        }
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
        return _compliance.getModules();
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

    /// Override ERC20 functions to add compliance checks
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        if (from != address(0) && to != address(0)) {
            require(_compliance.canTransfer(address(this), from, to, amount), "Transfer not compliant");
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._afterTokenTransfer(from, to, amount);
        if (from != address(0) && to != address(0)) {
            _compliance.transferred(address(this), from, to, amount);
        }
    }
}
