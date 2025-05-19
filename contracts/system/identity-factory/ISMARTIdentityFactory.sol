// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

/// @title ISMARTIdentityFactory Interface
/// @author SettleMint Tokenization Services
/// @notice This interface defines the functions for a factory contract responsible for creating and managing
///         on-chain identities for both user wallets and token contracts within the SMART Protocol.
/// @dev These identities are typically based on standards like ERC725 (OnchainID) and are deployed as proxy contracts
///      to allow for upgradeability. The factory pattern ensures that identities are created in a consistent and
/// predictable manner.
interface ISMARTIdentityFactory {
    // --- State-Changing Functions ---

    /// @notice Creates a new on-chain identity for a given user wallet address.
    /// @dev This function is expected to deploy a new identity contract (e.g., a `SMARTIdentityProxy`)
    ///      and associate it with the `_wallet` address. It may also set up initial management keys for the identity.
    ///      The creation process often involves deterministic deployment using CREATE2 for predictable addresses.
    /// @param _wallet The wallet address for which the identity is being created. This address might also serve as an
    /// initial manager.
    /// @param _managementKeys An array of `bytes32` representing pre-hashed management keys to be added to the new
    /// identity.
    ///                        These keys grant administrative control over the identity contract according to
    /// ERC734/ERC725 standards.
    /// @return identityContract The address of the newly deployed identity contract.
    function createIdentity(
        address _wallet,
        bytes32[] calldata _managementKeys
    )
        external
        returns (address identityContract);

    /// @notice Creates a new on-chain identity specifically for a token contract.
    /// @dev This function is expected to deploy a new identity contract (e.g., a `SMARTTokenIdentityProxy`)
    ///      and associate it with the `_token` contract address. An `_tokenOwner` is specified to manage this token
    /// identity.
    /// @param _token The address of the token contract for which the identity is being created.
    /// @param _tokenOwner The address that will be designated as the owner or initial manager of the token's identity.
    /// @return tokenIdentityContract The address of the newly deployed token identity contract.
    function createTokenIdentity(
        address _token,
        address _tokenOwner
    )
        external
        returns (address tokenIdentityContract);

    // --- View Functions ---

    /// @notice Retrieves the address of an already created on-chain identity associated with a given user wallet.
    /// @param _wallet The wallet address to look up.
    /// @return identityContract The address of the identity contract if one exists for the wallet, otherwise
    /// `address(0)`.
    function getIdentity(address _wallet) external view returns (address identityContract);

    /// @notice Retrieves the address of an already created on-chain identity associated with a given token contract.
    /// @param _token The token contract address to look up.
    /// @return tokenIdentityContract The address of the token identity contract if one exists for the token, otherwise
    /// `address(0)`.
    function getTokenIdentity(address _token) external view returns (address tokenIdentityContract);

    /// @notice Calculates the deterministic address at which an identity contract for a user wallet *would be* or *was*
    /// deployed.
    /// @dev This function typically uses the CREATE2 opcode logic to predict the address based on the factory's
    /// address,
    ///      a unique salt (often derived from `_walletAddress`), and the creation code of the identity proxy contract,
    ///      including its constructor arguments like `_initialManager`.
    /// @param _walletAddress The wallet address for which the identity address is being calculated.
    /// @param _initialManager The address that would be (or was) set as the initial manager during the identity's
    /// creation.
    /// @return predictedAddress The pre-computed or actual deployment address of the wallet's identity contract.
    function calculateWalletIdentityAddress(
        address _walletAddress,
        address _initialManager
    )
        external
        view
        returns (address predictedAddress);

    /// @notice Calculates the deterministic address at which an identity contract for a token *would be* or *was*
    /// deployed.
    /// @dev Similar to `calculateWalletIdentityAddress`, but for token identities. It uses a salt often derived from
    /// `_tokenAddress`.
    /// @param _tokenAddress The token contract address for which the identity address is being calculated.
    /// @param _initialManager The address that would be (or was) set as the initial manager during the token identity's
    /// creation.
    /// @return predictedAddress The pre-computed or actual deployment address of the token's identity contract.
    function calculateTokenIdentityAddress(
        address _tokenAddress,
        address _initialManager
    )
        external
        view
        returns (address predictedAddress);
}
