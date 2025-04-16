// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMARTCompliance } from "./interface/ISMARTCompliance.sol";
import { ISMARTComplianceModule } from "./interface/ISMARTComplianceModule.sol";
import { ISMART } from "./interface/ISMART.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title SMARTCompliance
/// @notice Implementation of the compliance contract for SMART tokens
contract SMARTCompliance is ISMARTCompliance, Ownable {
    // --- Constructor ---
    constructor() Ownable(msg.sender) { }

    // --- State-Changing Functions ---

    /// @inheritdoc ISMARTCompliance
    function transferred(address _token, address _from, address _to, uint256 _amount) external override {
        address[] memory modules = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modules.length; i++) {
            ISMARTComplianceModule(modules[i]).transferred(_token, _from, _to, _amount);
        }
    }

    /// @inheritdoc ISMARTCompliance
    function created(address _token, address _to, uint256 _amount) external override {
        address[] memory modules = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modules.length; i++) {
            ISMARTComplianceModule(modules[i]).created(_token, _to, _amount);
        }
    }

    /// @inheritdoc ISMARTCompliance
    function destroyed(address _token, address _from, uint256 _amount) external override {
        address[] memory modules = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modules.length; i++) {
            ISMARTComplianceModule(modules[i]).destroyed(_token, _from, _amount);
        }
    }

    // --- View Functions ---

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
        address[] memory modules = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modules.length; i++) {
            ISMARTComplianceModule(modules[i]).canTransfer(_token, _from, _to, _amount);
        }
        return true;
    }

    // --- Internal Functions ---
    // (No internal functions)
}
