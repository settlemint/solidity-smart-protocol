// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Identity } from "@onchainid/contracts/Identity.sol";
import { IIdentity } from "@onchainid/contracts/interface/IIdentity.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

/// @title SMART Token Identity Implementation Contract
/// @author SettleMint Tokenization Services
/// @notice This contract serves as the logic implementation for token-bound identities within the SMART Protocol.
/// Token-bound identities are on-chain identities (ERC725/ERC734 compliant via OnchainID's `Identity` contract)
/// that are specifically associated with a token contract, such as representing the token issuer or the token itself.
/// @dev This contract is designed to be deployed as a singleton logic contract. Multiple `SMARTTokenIdentityProxy`
/// instances will delegate their calls to this single implementation.
/// It inherits from `Identity` to provide the core ERC725 (Identity) and ERC734 (Key Management) functionalities.
/// It also inherits from `ERC165Upgradeable` to support interface detection (ERC165) in an upgradeable proxy context.
///
/// Key considerations and future improvements (TODOs):
/// 1.  **Management Linkage**: The management keys and permissions for this identity should ideally be linked to,
///     or derived from, the access control mechanisms of the associated token contract it represents.
///     This would ensure that control over the token naturally extends to control over its on-chain identity.
/// 2.  **Meta-transaction Support (ERC2771)**: For broader usability, especially with wallets that may not hold ETH
///     for gas fees, this contract should be made compatible with ERC2771 (trusted forwarders).
///     This would involve inheriting from `ERC2771ContextUpgradeable` and using `_msgSender()` appropriately.
/// 3.  **ERC165 Initialization**: The standard pattern for initializing `ERC165Upgradeable` in an upgradeable contract
///     is to call `__ERC165_init_unchained()` within an `initialize` function. This contract currently lacks an
///     explicit initializer, which is acceptable for a non-upgradeable logic contract, but if it were to be made
///     directly upgradeable itself (not just via proxy), this would need to be addressed. Proxies calling this
///     will handle their own initialization patterns for upgradeability.
contract SMARTTokenIdentityImplementation is Identity, ERC165Upgradeable {
    /// @notice Constructor for the `SMARTTokenIdentityImplementation` contract.
    /// @dev This constructor is called only once when this logic contract is deployed to the blockchain.
    /// It calls the constructor of the parent `Identity` contract with specific parameters:
    /// -   `owner`: `address(0)` is passed, meaning the identity is not initially owned or managed by another external
    /// identity contract.
    ///      Management and ownership keys are typically set up later, often through an `initialize` function called by
    /// a proxy,
    ///      or directly by the deployer adding keys if the contract were not intended for proxy usage.
    /// -   `selfManagement`: `true` is passed. This parameter in the OnchainID `Identity` constructor typically means
    ///      that the deployer of the `Identity` contract is *not* automatically granted management keys.
    ///      Instead, for `SMARTTokenIdentityProxy` instances using this logic, the initial management key(s)
    ///      (e.g., the address of the token owner or the token contract itself) are established during the proxy's
    ///      initialization process (via a `delegatecall` to an `initialize` function that this contract would provide
    /// if it had one, or by direct key additions post-deployment if used standalone).
    /// As this is a logic contract for proxies, its own constructor state related to `ERC165Upgradeable` is less
    /// critical
    /// than the initialization within the proxy context. If this contract had an `initialize` function for proxy use,
    /// `__ERC165_init_unchained()` would typically be called there.
    constructor() Identity(address(0), true) {
        // ERC165Upgradeable initialization for this specific logic contract instance itself is implicitly handled.
        // If this contract were to be made *itself* upgradeable (not just serving as an implementation for proxies),
        // an initializer function (e.g., `initializeSMARTTokenIdentity()`) would be added, and
        // `__ERC165_init_unchained()` would be called within that initializer.
        // For its role as a proxy implementation, the proxy's initializer handles ERC165 setup for the proxy storage.
    }

    /// @inheritdoc IERC165
    /// @notice Checks if this contract (or the contract it's an implementation for, via `delegatecall`)
    /// supports a given interface ID, according to the ERC165 standard.
    /// @dev This function overrides `supportsInterface` from `ERC165Upgradeable`.
    /// It explicitly declares support for:
    /// -   `type(IIdentity).interfaceId`: This indicates compliance with the `IIdentity` interface from OnchainID,
    ///     which encompasses ERC725 (Identity) and ERC734 (Key Management) functionalities.
    /// -   `type(IERC165).interfaceId`: This indicates compliance with the ERC165 interface detection standard itself.
    /// It then calls `super.supportsInterface(interfaceId)` to include support for any interfaces registered
    /// by parent contracts further up the inheritance chain (e.g., `Identity` itself might register others if it
    /// inherited `ERC165`).
    /// This ensures a complete and accurate report of all supported interfaces.
    /// @param interfaceId The EIP-165 interface identifier (a `bytes4` value) to check for support.
    /// @return `true` if the contract supports the specified `interfaceId`, `false` otherwise.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
        return interfaceId == type(IIdentity).interfaceId || interfaceId == type(IERC165).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
