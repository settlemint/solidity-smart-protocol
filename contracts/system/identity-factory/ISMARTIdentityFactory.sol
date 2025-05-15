// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

interface ISMARTIdentityFactory {
    // --- State-Changing Functions ---
    function createIdentity(address _wallet, bytes32[] calldata _managementKeys) external returns (address);
    function createTokenIdentity(address _token, address _tokenOwner) external returns (address);

    // --- View Functions ---
    function getIdentity(address _wallet) external view returns (address);
    function getTokenIdentity(address _token) external view returns (address);

    function calculateWalletIdentityAddress(
        address _walletAddress,
        address _initialManager
    )
        external
        view
        returns (address);

    function calculateTokenIdentityAddress(
        address _tokenAddress,
        address _initialManager
    )
        external
        view
        returns (address);
}
