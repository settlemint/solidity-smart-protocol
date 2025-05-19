// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

interface ISMARTTokenFactory {
    /// @notice Initializes the token registry.
    /// @param systemAddress The address of the `ISMARTSystem` contract.
    /// @param tokenImplementation_ The address of the token implementation contract.
    /// @param initialAdmin The address of the initial admin for the token registry.
    function initialize(address systemAddress, address tokenImplementation_, address initialAdmin) external;

    /// @notice Returns the address of the token implementation contract.
    /// @return tokenImplementation The address of the token implementation contract.
    function tokenImplementation() external view returns (address);

    /// @notice Returns the address of the token implementation contract.
    /// @return tokenImplementation The address of the token implementation contract.
    function isValidTokenImplementation(address tokenImplementation_) external view returns (bool);
}
