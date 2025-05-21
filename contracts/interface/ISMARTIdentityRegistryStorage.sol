// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity ^0.8.28;

import { IERC3643IdentityRegistryStorage } from "./ERC-3643/IERC3643IdentityRegistryStorage.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";

interface ISMARTIdentityRegistryStorage is IERC3643IdentityRegistryStorage {
    /// events

    /// @dev This event is emitted when an Identity is registered into the storage contract.
    /// @param _investorAddress` is the address of the investor's wallet.
    /// @param _identity` is the address of the Identity smart contract (onchainID).
    event IdentityStored(address indexed _investorAddress, IIdentity indexed _identity);

    /// @dev This event is emitted when an Identity is removed from the storage contract.
    /// @param _investorAddress is the address of the investor's wallet.
    /// @param _identity is the address of the Identity smart contract (onchainID).
    event IdentityUnstored(address indexed _investorAddress, IIdentity indexed _identity);

    /// @dev This event is emitted when an Identity has been updated.
    /// @param _oldIdentity is the old Identity contract's address to update.
    /// @param _newIdentity is the new Identity contract's.
    event IdentityModified(IIdentity indexed _oldIdentity, IIdentity indexed _newIdentity);

    /// @dev This event is emitted when an Identity's country has been updated.
    /// @param _investorAddress is the address on which the country has been updated.
    /// @param _country is the numeric code (ISO 3166-1) of the new country.
    event CountryModified(address indexed _investorAddress, uint16 indexed _country);

    /// @dev This event is emitted when an Identity Registry is bound to the storage contract.
    /// @param _identityRegistry is the address of the identity registry added.
    event IdentityRegistryBound(address indexed _identityRegistry);

    /// @dev This event is emitted when an Identity Registry is unbound from the storage contract.
    /// @param _identityRegistry is the address of the identity registry removed.
    event IdentityRegistryUnbound(address indexed _identityRegistry);

    /// @notice Emitted when a user wallet is marked as lost for a specific identity contract within the storage.
    /// @param identityContract The IIdentity contract associated with the user wallet.
    /// @param userWallet The user wallet address that was marked as lost.
    /// @param markedBy The address (typically the Identity Registry contract) that initiated this action.
    event IdentityWalletMarkedAsLost(
        address indexed identityContract, address indexed userWallet, address indexed markedBy
    );

    // --- Lost Wallet Management ---

    /// @notice Marks a user wallet as lost for a specific identity contract in the storage.
    /// @dev Called by an authorized Identity Registry. This indicates the wallet should no longer be considered active
    ///      for verification or operations related to this specific identity, and potentially globally.
    /// @param identityContract The IIdentity contract address to which the userWallet was associated.
    /// @param userWallet The user wallet address to be marked as lost.
    function markWalletAsLost(address identityContract, address userWallet) external;

    /// @notice Checks if a user wallet is globally marked as lost in the storage.
    /// @dev A "globally lost" wallet means it has been declared lost in the context of at least one identity
    ///      it was associated with.
    /// @param userWallet The user wallet address to check.
    /// @return True if the wallet has been marked as lost at least once, false otherwise.
    function isWalletMarkedAsLost(address userWallet) external view returns (bool);

    /// @notice Checks if a user wallet is marked as lost for a specific IIdentity contract in the storage.
    /// @param identityContract The IIdentity contract address.
    /// @param userWallet The user wallet address to check.
    /// @return True if the wallet has been marked as lost for the identity, false otherwise.
    function isWalletMarkedAsLostForIdentity(
        address identityContract,
        address userWallet
    )
        external
        view
        returns (bool);

    /// @notice Retrieves all wallet addresses that have been marked as lost for a specific IIdentity contract.
    /// @param identityContract The IIdentity contract address.
    /// @return An array of wallet addresses marked as lost for this identity.
    function getLostWalletsForIdentityFromStorage(address identityContract) external view returns (address[] memory);
}
