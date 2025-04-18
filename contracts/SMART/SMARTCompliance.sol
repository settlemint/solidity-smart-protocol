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
/// @notice Implementation of the compliance contract for SMART tokens (Upgradeable, ERC-2771 compatible)
contract SMARTCompliance is
    Initializable,
    ISMARTCompliance,
    ERC2771ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // --- Constructor ---
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC2771ContextUpgradeable(address(0)) {
        // Initialize parent constructor
        _disableInitializers();
    }

    /// @notice Initializes the contract after deployment through a proxy.
    /// @param initialOwner The address to grant ownership to.
    // No trustedForwarder param needed here anymore
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner); // Calls __Context_init indirectly
        __UUPSUpgradeable_init();
        // __ERC2771Context_init(trustedForwarder); // No longer exists/needed
    }

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

    /// @inheritdoc ContextUpgradeable
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /// @inheritdoc ContextUpgradeable
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    /// @inheritdoc ERC2771ContextUpgradeable
    function _contextSuffixLength()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength(); // Explicitly use ERC2771 version
    }

    /// @dev Authorizes an upgrade to a new implementation contract. Only the owner can authorize.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
