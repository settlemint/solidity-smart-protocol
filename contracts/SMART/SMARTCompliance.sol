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
        ISMART.ComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            ISMARTComplianceModule(modulePairs[i].module).transferred(
                _token, _from, _to, _amount, modulePairs[i].params
            );
        }
    }

    /// @inheritdoc ISMARTCompliance
    function created(address _token, address _to, uint256 _amount) external override {
        ISMART.ComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            ISMARTComplianceModule(modulePairs[i].module).created(_token, _to, _amount, modulePairs[i].params);
        }
    }

    /// @inheritdoc ISMARTCompliance
    function destroyed(address _token, address _from, uint256 _amount) external override {
        ISMART.ComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            ISMARTComplianceModule(modulePairs[i].module).destroyed(_token, _from, _amount, modulePairs[i].params);
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
        ISMART.ComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            ISMARTComplianceModule(modulePairs[i].module).canTransfer(
                _token, _from, _to, _amount, modulePairs[i].params
            );
        }
        return true;
    }

    // --- Internal Functions ---
    // (No internal functions)
}
