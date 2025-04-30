// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

// OpenZeppelin imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { AccessControlDefaultAdminRulesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// Interface imports
import { ISMARTCompliance } from "./interface/ISMARTCompliance.sol";
import { ISMARTComplianceModule } from "./interface/ISMARTComplianceModule.sol";
import { ISMART } from "./interface/ISMART.sol";
import { SMARTComplianceModuleParamPair } from "./interface/structs/SMARTComplianceModuleParamPair.sol";
import { ZeroAddressNotAllowed } from "./extensions/common/CommonErrors.sol";

/// @title SMART Compliance Contract
/// @notice Upgradeable implementation of the main compliance contract for SMART tokens.
/// @dev This contract orchestrates compliance checks and notifications by delegating to registered
///      compliance modules associated with a specific ISMART token.
///      It uses AccessControl for administration and UUPS for upgradeability.
contract SMARTCompliance is
    Initializable,
    ISMARTCompliance,
    ERC2771ContextUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    UUPSUpgradeable
{
    // --- Errors ---
    error InvalidModuleImplementation();

    // --- Constructor --- (Disable direct construction)
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
    }

    // --- Initializer ---
    /// @notice Initializes the compliance contract.
    /// @dev Sets up AccessControl with default admin rules and UUPS upgradeability.
    /// @param initialAdmin The address that will receive the `DEFAULT_ADMIN_ROLE`.
    function initialize(address initialAdmin) public initializer {
        // Order: AccessControl -> DefaultAdminRules -> UUPS
        __AccessControl_init();
        __AccessControlDefaultAdminRules_init(3 days, initialAdmin); // Sets admin with delay
        __UUPSUpgradeable_init();
        // ERC2771Context is initialized by the constructor
    }

    // --- ISMARTCompliance Implementation (State-Changing) ---

    /// @inheritdoc ISMARTCompliance
    /// @dev Iterates through all compliance modules registered with the token and calls their `transferred` hook.
    ///      This function is expected to be called ONLY by the associated ISMART token contract.
    function transferred(address _token, address _from, address _to, uint256 _amount) external override {
        // Note: Access control check (is _msgSender() the token?) might be needed depending on architecture.
        // Currently assumes only the bound token calls this.
        SMARTComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            ISMARTComplianceModule(modulePairs[i].module).transferred(
                _token, _from, _to, _amount, modulePairs[i].params
            );
        }
    }

    /// @inheritdoc ISMARTCompliance
    /// @dev Iterates through all compliance modules registered with the token and calls their `created` hook.
    ///      This function is expected to be called ONLY by the associated ISMART token contract.
    function created(address _token, address _to, uint256 _amount) external override {
        SMARTComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            ISMARTComplianceModule(modulePairs[i].module).created(_token, _to, _amount, modulePairs[i].params);
        }
    }

    /// @inheritdoc ISMARTCompliance
    /// @dev Iterates through all compliance modules registered with the token and calls their `destroyed` hook.
    ///      This function is expected to be called ONLY by the associated ISMART token contract.
    function destroyed(address _token, address _from, uint256 _amount) external override {
        SMARTComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            ISMARTComplianceModule(modulePairs[i].module).destroyed(_token, _from, _amount, modulePairs[i].params);
        }
    }

    // --- ISMARTCompliance Implementation (View) ---
    /// @inheritdoc ISMARTCompliance
    function isValidComplianceModule(address _module, bytes calldata _params) external view virtual override {
        _validateModuleAndParams(_module, _params);
    }

    /// @inheritdoc ISMARTCompliance
    function areValidComplianceModules(SMARTComplianceModuleParamPair[] calldata _pairs)
        external
        view
        virtual
        override
    {
        for (uint256 i = 0; i < _pairs.length; i++) {
            _validateModuleAndParams(_pairs[i].module, _pairs[i].params);
        }
    }

    /// @inheritdoc ISMARTCompliance
    /// @dev Iterates through all compliance modules registered with the token and calls their `canTransfer` view
    /// function.
    ///      If any module reverts, the entire call reverts, indicating the transfer is not compliant.
    ///      Returns true if all modules allow the transfer.
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
        SMARTComplianceModuleParamPair[] memory modulePairs = ISMART(_token).complianceModules();
        for (uint256 i = 0; i < modulePairs.length; i++) {
            // Each module's canTransfer will revert if the check fails.
            ISMARTComplianceModule(modulePairs[i].module).canTransfer(
                _token, _from, _to, _amount, modulePairs[i].params
            );
        }
        // If no module reverted, the transfer is considered compliant by this contract.
        return true;
    }

    // -- Internal Validation Function --

    /// @dev Internal function to validate a compliance module's interface support AND its parameters.
    ///      Reverts with appropriate error if validation fails.
    /// @param _module The address of the compliance module to validate.
    /// @param _params The parameters to validate against the module.
    function _validateModuleAndParams(address _module, bytes memory _params) private view {
        if (_module == address(0)) revert ZeroAddressNotAllowed();

        // Check if the module supports the ISMARTComplianceModule interface
        try IERC165(_module).supportsInterface(type(ISMARTComplianceModule).interfaceId) returns (bool supported) {
            if (!supported) {
                revert InvalidModuleImplementation(); // Revert if the interface is not supported
            }
        } catch {
            revert InvalidModuleImplementation(); // Revert if the supportsInterface call fails
        }

        // Validate the provided parameters using the module's validation function
        // This external call can revert, which will propagate up.
        ISMARTComplianceModule(_module).validateParameters(_params);
    }

    // --- Context Overrides (ERC2771) ---

    /// @dev Returns the message sender, potentially extracting it from the end of `msg.data` if using a trusted
    /// forwarder.
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /// @dev Returns the full `msg.data`, potentially excluding the address suffix if using a trusted forwarder.
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    /// @dev Hook defining the length of the trusted forwarder address suffix in `msg.data`.
    function _contextSuffixLength()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    // --- Upgradeability (UUPS) ---

    /// @dev Authorizes an upgrade to a new implementation.
    ///      Requires the caller to have the `DEFAULT_ADMIN_ROLE`.
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
