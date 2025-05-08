// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

// OpenZeppelin imports
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title ISMART Compliance Module Interface
/// @notice Defines the interface for individual compliance modules used by an ISMARTCompliance contract.
///         Modules implement specific compliance rules or actions.
interface ISMARTComplianceModule is IERC165 {
    // --- Custom Errors ---
    /// @notice Reverted by `canTransfer` if the module's compliance check fails.
    /// @param reason A descriptive reason for the compliance failure.
    error ComplianceCheckFailed(string reason);
    /// @notice Reverted by `validateParameters` if the provided parameters are invalid for this module.
    /// @param reason A descriptive reason why the parameters are invalid.
    error InvalidParameters(string reason);

    // --- Core Functions ---

    /**
     * @notice Checks if a potential transfer complies with this module's rules.
     * @dev This function MUST be view only and should not modify state.
     *      It should revert with `ComplianceCheckFailed` if the transfer is not allowed by this module.
     *      It is called by the main `ISMARTCompliance` contract's `canTransfer`.
     * @param _token Address of the ISMART token contract.
     * @param _from Address of the transfer sender (address(0) for mints).
     * @param _to Address of the transfer receiver (address(0) for burns).
     * @param _value Amount of tokens involved in the potential transfer.
     * @param _params Token-specific parameters configured for this module instance.
     */
    function canTransfer(
        address _token,
        address _from,
        address _to,
        uint256 _value,
        bytes calldata _params
    )
        external
        view;

    /**
     * @notice Called by the main `ISMARTCompliance` contract AFTER a successful transfer occurs.
     * @dev This function can modify the module's state if needed (e.g., update limits).
     * @param _token Address of the ISMART token contract.
     * @param _from Address of the transfer sender.
     * @param _to Address of the transfer receiver.
     * @param _value Amount of tokens transferred.
     * @param _params Token-specific parameters configured for this module instance.
     */
    function transferred(address _token, address _from, address _to, uint256 _value, bytes calldata _params) external;

    /**
     * @notice Called by the main `ISMARTCompliance` contract AFTER a successful mint operation occurs.
     * @dev This function can modify the module's state if needed.
     * @param _token Address of the ISMART token contract.
     * @param _to Address where tokens were minted.
     * @param _value Amount of tokens minted.
     * @param _params Token-specific parameters configured for this module instance.
     */
    function created(address _token, address _to, uint256 _value, bytes calldata _params) external;

    /**
     * @notice Called by the main `ISMARTCompliance` contract AFTER a successful burn/redeem operation occurs.
     * @dev This function can modify the module's state if needed.
     * @param _token Address of the ISMART token contract.
     * @param _from Address from which tokens were burned.
     * @param _value Amount of tokens burned.
     * @param _params Token-specific parameters configured for this module instance.
     */
    function destroyed(address _token, address _from, uint256 _value, bytes calldata _params) external;

    /**
     * @notice Validates the format and content of configuration parameters intended for this module.
     * @dev This function MUST be view only and should not modify state.
     *      It is called by the ISMART token contract when adding a module (`addComplianceModule`)
     *      or updating parameters (`setParametersForComplianceModule`).
     *      It should revert with `InvalidParameters` if the parameters are not valid for this module.
     * @param _params The ABI-encoded parameters to validate.
     */
    function validateParameters(bytes calldata _params) external view;

    /**
     * @notice Returns the human-readable name of the compliance module.
     * @dev Should be a pure function.
     * @return The name of the module.
     */
    function name() external pure returns (string memory);
}
