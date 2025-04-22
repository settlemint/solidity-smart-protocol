// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMARTCompliance } from "./interface/ISMARTCompliance.sol";
import { ISMARTComplianceModule } from "./interface/ISMARTComplianceModule.sol";
import { ISMART } from "./interface/ISMART.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

/// @title SMARTCompliance
/// @notice Implementation of the compliance contract for SMART tokens.
contract SMARTCompliance is
    Initializable,
    ISMARTCompliance,
    ERC2771ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // --- Constructor ---
    constructor() ERC2771ContextUpgradeable(address(0)) {
        _disableInitializers();
    }

    // --- Initializer ---
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    // --- State-Changing Functions ---
    function transferred(address _token, address _from, address _to, uint256 _amount) external override {
        ISMART.ComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            ISMARTComplianceModule(modulePairs[i].module).transferred(
                _token, _from, _to, _amount, modulePairs[i].params
            );
        }
    }

    function created(address _token, address _to, uint256 _amount) external override {
        ISMART.ComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            ISMARTComplianceModule(modulePairs[i].module).created(_token, _to, _amount, modulePairs[i].params);
        }
    }

    function destroyed(address _token, address _from, uint256 _amount) external override {
        ISMART.ComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            ISMARTComplianceModule(modulePairs[i].module).destroyed(_token, _from, _amount, modulePairs[i].params);
        }
    }

    // --- View Functions ---
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
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    // --- Upgradeability ---
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
