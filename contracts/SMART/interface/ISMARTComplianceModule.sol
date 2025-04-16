// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

/// @title ISMARTComplianceModule
/// @notice Interface for SMART compliance modules
interface ISMARTComplianceModule {
    /// Custom Errors
    error ComplianceCheckFailed(string reason);

    /// Functions
    /**
     * @dev Action performed on the module during a transfer action
     * @param _token Address of the token
     * @param _from Address of the transfer sender
     * @param _to Address of the transfer receiver
     * @param _value Amount of tokens sent
     */
    function transferred(address _token, address _from, address _to, uint256 _value) external;

    /**
     * @dev Action performed on the module during a mint action
     * @param _token Address of the token
     * @param _to Address used for minting
     * @param _value Amount of tokens minted
     */
    function created(address _token, address _to, uint256 _value) external;

    /**
     * @dev Action performed on the module during a burn action
     * @param _token Address of the token
     * @param _from Address on which tokens are burnt
     * @param _value Amount of tokens burnt
     */
    function destroyed(address _token, address _from, uint256 _value) external;

    /**
     * @dev Performs a compliance check for a transaction.
     *      Reverts with ComplianceCheckFailed(string reason) if the check fails.
     * @param _token Address of the token
     * @param _from Address of the transfer sender
     * @param _to Address of the transfer receiver
     * @param _value Amount of tokens sent
     */
    function canTransfer(address _token, address _from, address _to, uint256 _value) external view;

    /**
     * @dev Getter for the name of the module
     * @return string The name of the module
     */
    function name() external pure returns (string memory);
}
