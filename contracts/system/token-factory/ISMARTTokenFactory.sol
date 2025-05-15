// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

interface ISMARTTokenFactory {
    /// @notice Initializes the token registry.
    /// @param initialAdmin The address of the initial admin for the token registry.
    /// @param tokenImplementation The address of the token implementation contract.
    function initialize(address initialAdmin, address tokenImplementation) external;

    /// @notice Returns the address of the token implementation contract.
    /// @return tokenImplementation The address of the token implementation contract.
    function tokenImplementation() external view returns (address);
}
