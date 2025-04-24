// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

/// @title ISMARTCompliance
/// @notice Interface for the compliance contract used by SMART tokens
interface ISMARTCompliance {
    /// @notice Called whenever tokens are transferred from one wallet to another
    /// @dev This function can only be called by the token contract bound to the compliance
    /// @param _token The address of the token
    /// @param _from The address of the sender
    /// @param _to The address of the receiver
    /// @param _amount The amount of tokens involved in the transfer
    function transferred(address _token, address _from, address _to, uint256 _amount) external;

    /// @notice Called whenever tokens are created on a wallet
    /// @dev This function can only be called by the token contract bound to the compliance
    /// @param _token The address of the token
    /// @param _to The address of the receiver
    /// @param _amount The amount of tokens involved in the minting
    function created(address _token, address _to, uint256 _amount) external;

    /// @notice Called whenever tokens are destroyed from a wallet
    /// @dev This function can only be called by the token contract bound to the compliance
    /// @param _token The address of the token
    /// @param _from The address on which tokens are burnt
    /// @param _amount The amount of tokens involved in the burn
    function destroyed(address _token, address _from, uint256 _amount) external;

    /// @notice Checks that the transfer is compliant
    /// @dev READ ONLY FUNCTION, this function cannot be used to increment counters, emit events, etc.
    /// @param _token The address of the token
    /// @param _from The address of the sender
    /// @param _to The address of the receiver
    /// @param _amount The amount of tokens involved in the transfer
    /// @return True if the transfer is compliant, reverts if not
    function canTransfer(address _token, address _from, address _to, uint256 _amount) external view returns (bool);
}
