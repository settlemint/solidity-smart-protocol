// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Identity } from "@onchainid/contracts/Identity.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

/// @title SMART Identity Implementation Contract (Logic for Wallet Identities)
/// @author SettleMint Tokenization Services
/// @notice This contract provides the upgradeable logic for standard on-chain identities associated with user wallets
///         within the SMART Protocol. It is based on the OnchainID `Identity` contract (ERC725/ERC734).
/// @dev This contract is intended to be deployed once and then used as the logic implementation target for multiple
///      `SMARTIdentityProxy` contracts. It inherits `Identity` for core ERC725/734 functionality and
///      `ERC165Upgradeable` for interface detection in an upgradeable context.
///      TODO: This implementation needs to be made ERC-2771 compatible for meta-transaction support if intended to be
/// used with a trusted forwarder directly.
///      TODO: The ERC-165 initialization pattern should be reviewed; typically `__ERC165_init_unchained()` is called in
/// an `initialize` function for upgradeable contracts, not directly via constructor inheritance if this itself is meant
/// to be proxied (though here it serves as a logic target).
contract SMARTIdentityImplementation is Identity, ERC165Upgradeable {
    /// @notice Constructor for the `SMARTIdentityImplementation`.
    /// @dev Calls the constructor of the parent `Identity` contract.
    ///      - `address(0)`: This indicates that the identity contract itself is not initially owned by another identity
    /// contract.
    ///      - `true`: This boolean likely signifies that the deployer (`msg.sender` of this logic contract deployment,
    /// if deployed directly)
    ///                is *not* automatically added as a management key. The `initialize` function called via
    /// `delegatecall` by the proxy
    ///                is responsible for setting up the initial management key(s) for each specific identity instance.
    ///      This constructor will only be called once when this logic contract is deployed.
    ///      For proxied identities, the state (including keys and claims) is managed in the proxy's storage,
    /// initialized via `delegatecall` to `Identity.initialize(initialManagementKey)`.
    constructor() Identity(address(0), true) {
        // ERC165Upgradeable does not have an explicit constructor to call here.
        // Its initialization (`__ERC165_init_unchained`) is handled if this contract had an `initialize` function, or
        // implicitly by its own constructor if not further initialized.
        // Given the TODO, this might need an `initialize` function if it were to become an upgradeable contract itself
        // rather than just a logic target.
    }

    /// @inheritdoc IERC165
    /// @notice Checks if the contract supports a given interface ID.
    /// @dev It declares support for `IIdentity` (from OnchainID, covering ERC725/734 aspects)
    ///      and `IERC165` (the interface detection standard itself).
    ///      It also calls `super.supportsInterface(interfaceId)` to include support for interfaces from other parent
    /// contracts.
    ///      The `Identity` contract also implements `supportsInterface` from OpenZeppelin's `ERC165`.
    ///      This override ensures correct chaining and explicit support declaration for `IIdentity` and `IERC165` via
    /// `ERC165Upgradeable`.
    /// @param interfaceId The interface identifier (bytes4) to check.
    /// @return `true` if the contract supports the `interfaceId`, `false` otherwise.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
        return interfaceId == type(IIdentity).interfaceId || interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
