// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import { ISMART } from "./ISMART.sol";
import { SMARTComplianceModuleParamPair } from "./structs/SMARTComplianceModuleParamPair.sol";

/// @title ISMART Compliance Interface
/// @notice Defines the interface for the main compliance contract used by SMART tokens.
///         This contract is responsible for checking transfer legality and potentially logging/acting on transfers.

interface ISMARTCompliance {
    /// @notice Checks if a transfer is compliant according to the rules enforced by this contract and its modules.
    /// @dev This function MUST be view only and should not modify state. It should revert if the transfer is not
    /// allowed.
    ///      It typically delegates checks to registered compliance modules.
    /// @param _token The address of the ISMART token contract initiating the check.
    /// @param _from The sender address (address(0) for mints).
    /// @param _to The recipient address (address(0) for burns).
    /// @param _amount The amount of tokens involved in the potential transfer.
    /// @return True if the transfer is compliant, otherwise reverts.
    function canTransfer(address _token, address _from, address _to, uint256 _amount) external view returns (bool);

    /// @notice Called by the token contract AFTER a successful transfer occurs.
    /// @dev This function can modify state (e.g., update counters, log). It should only be callable by the bound token
    /// contract.
    ///      It typically notifies registered compliance modules.
    /// @param _token The address of the ISMART token contract where the transfer occurred.
    /// @param _from The sender address.
    /// @param _to The recipient address.
    /// @param _amount The amount of tokens transferred.
    function transferred(address _token, address _from, address _to, uint256 _amount) external;

    /// @notice Called by the token contract AFTER a successful mint operation occurs.
    /// @dev This function can modify state. It should only be callable by the bound token contract.
    ///      It typically notifies registered compliance modules.
    /// @param _token The address of the ISMART token contract where the mint occurred.
    /// @param _to The recipient address.
    /// @param _amount The amount of tokens minted.
    function created(address _token, address _to, uint256 _amount) external;

    /// @notice Called by the token contract AFTER a successful burn/redeem operation occurs.
    /// @dev This function can modify state. It should only be callable by the bound token contract.
    ///      It typically notifies registered compliance modules.
    /// @param _token The address of the ISMART token contract where the burn occurred.
    /// @param _from The address whose tokens were burned.
    /// @param _amount The amount of tokens burned.
    function destroyed(address _token, address _from, uint256 _amount) external;

    // --- Compliance Module Validation (Views) ---

    /// @notice Validates if a module implements the required interface AND if the provided parameters are valid for it.
    /// @dev Reverts if the module address is invalid, does not support `ISMARTComplianceModule`, or if parameters are
    /// rejected by the module's `validateParameters`.
    /// @param _module The address of the module to validate.
    /// @param _params The parameters to validate against the module.
    function isValidComplianceModule(address _module, bytes calldata _params) external view;

    /// @notice Validates multiple compliance modules and their corresponding parameters.
    /// @dev Reverts if any pair in the array fails the checks performed by `isValidComplianceModule`.
    /// @param _pairs An array of module-parameter pairs to validate.
    function areValidComplianceModules(SMARTComplianceModuleParamPair[] calldata _pairs) external view;
}
