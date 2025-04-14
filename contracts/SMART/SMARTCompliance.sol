// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMARTCompliance } from "./interface/ISmartCompliance.sol";
import { ISMARTComplianceModule } from "./interface/ISMARTComplianceModule.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title SMARTCompliance
/// @notice Implementation of the compliance contract for SMART tokens
contract SMARTCompliance is ISMARTCompliance, Ownable {
    /// Storage
    mapping(address => bool) private _complianceModules;
    address[] private _modules;

    /// Events
    event ModuleAdded(address indexed _module);
    event ModuleRemoved(address indexed _module);

    constructor() Ownable(msg.sender) { }

    /// @inheritdoc ISMARTCompliance
    function transferred(address _token, address _from, address _to, uint256 _amount) external override {
        for (uint256 i = 0; i < _modules.length; i++) {
            if (_complianceModules[_modules[i]]) {
                ISMARTComplianceModule(_modules[i]).moduleTransferAction(_token, _from, _to, _amount);
            }
        }
    }

    /// @inheritdoc ISMARTCompliance
    function created(address _token, address _to, uint256 _amount) external override {
        for (uint256 i = 0; i < _modules.length; i++) {
            if (_complianceModules[_modules[i]]) {
                ISMARTComplianceModule(_modules[i]).moduleMintAction(_token, _to, _amount);
            }
        }
    }

    /// @inheritdoc ISMARTCompliance
    function destroyed(address _token, address _from, uint256 _amount) external override {
        for (uint256 i = 0; i < _modules.length; i++) {
            if (_complianceModules[_modules[i]]) {
                ISMARTComplianceModule(_modules[i]).moduleBurnAction(_token, _from, _amount);
            }
        }
    }

    /// @inheritdoc ISMARTCompliance
    function canTransfer(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    )
        external
        view
        override
        returns (bool)
    {
        for (uint256 i = 0; i < _modules.length; i++) {
            if (_complianceModules[_modules[i]]) {
                (bool isCompliant, string memory reason) =
                    ISMARTComplianceModule(_modules[i]).moduleCheck(_token, _from, _to, _amount);
                if (!isCompliant) {
                    revert(reason);
                }
            }
        }
        return true;
    }

    /// @notice Get all compliance modules
    /// @return The array of compliance module addresses
    function getModules() external view returns (address[] memory) {
        return _modules;
    }

    /// @notice Check if an address is a compliance module
    /// @param _module The address to check
    /// @return Whether the address is a compliance module
    function isModule(address _module) external view returns (bool) {
        return _complianceModules[_module];
    }
}
