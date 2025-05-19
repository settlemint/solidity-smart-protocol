// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { ISMARTSystem } from "../../ISMARTSystem.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {
    InitializationFailed,
    IdentityImplementationNotSet,
    InvalidSystemAddress,
    ETHTransfersNotAllowed
} from "../../SMARTSystemErrors.sol";
import { ZeroAddressNotAllowed } from "../SMARTIdentityErrors.sol";
import { Identity } from "@onchainid/contracts/Identity.sol";
import { ISMARTTokenIdentity } from "./ISMARTTokenIdentity.sol";

/// @title SMART Token Identity Proxy Contract (for Token-Bound Identities)
/// @author SettleMint Tokenization Services
/// @notice This contract serves as an upgradeable proxy for an on-chain identity specifically bound to a token
/// contract.
///         It is based on the ERC725 (OnchainID) standard for identity and uses ERC734 for key management.
/// @dev This proxy contract adheres to EIP-1967 for upgradeability. It holds the token identity's storage
///      (keys, claims, etc.) and its public address, while delegating all logic calls to a
/// `SMARTTokenIdentityImplementation` contract.
///      The address of this logic implementation is retrieved from the central `ISMARTSystem` contract via
/// `tokenIdentityImplementation()`,
///      allowing the underlying token identity logic to be upgraded without changing this proxy's address or losing its
/// state.
///      This proxy is typically created by the `SMARTIdentityFactoryImplementation` for a specific token.
contract SMARTTokenIdentityProxy is Proxy {
    /// @dev Storage slot used to store the address of the `ISMARTSystem` contract, ensuring it doesn't collide with
    /// other storage variables.
    /// This specific slot `0x4daB14fe28c3f2b5015f84ab98dd06c520603d8d9f3317f1ae7537d2c65aef3c` is
    /// `keccak256("org.smart.contracts.proxy.SMARTTokenIdentityProxy.system")`.
    bytes32 private constant _SYSTEM_SLOT = 0x4daB14fe28c3f2b5015f84ab98dd06c520603d8d9f3317f1ae7537d2c65aef3c;

    /// @notice Internal function to securely store the address of the `ISMARTSystem` contract in the designated storage
    /// slot.
    /// @dev This is called once during the proxy's construction.
    /// @param system_ The instance of the `ISMARTSystem` contract to be stored.
    function _setSystem(ISMARTSystem system_) internal {
        StorageSlot.getAddressSlot(_SYSTEM_SLOT).value = address(system_);
    }

    /// @notice Internal function to securely retrieve the address of the `ISMARTSystem` contract from its storage slot.
    /// @dev This is used by the proxy to find out which `SMARTTokenIdentityImplementation` contract to delegate calls
    /// to.
    /// @return ISMARTSystem The instance of the `ISMARTSystem` contract currently configured for this proxy.
    function _getSystem() internal view returns (ISMARTSystem) {
        return ISMARTSystem(StorageSlot.getAddressSlot(_SYSTEM_SLOT).value);
    }

    /// @notice Constructor for the `SMARTTokenIdentityProxy`.
    /// @dev This function is called only once when this proxy contract is deployed (typically by the
    /// `SMARTIdentityFactory`).
    /// It initializes the proxy and the underlying token identity state:
    /// 1. Validates `systemAddress`: Ensures it's not `address(0)` and implements `ISMARTSystem` (via ERC165).
    /// 2. Stores `systemAddress` using `_setSystem`.
    /// 3. Validates `initialManagementKey`: Ensures it's not `address(0)`. This key will manage the token's identity.
    /// 4. Retrieves the `SMARTTokenIdentityImplementation` address from the `ISMARTSystem` contract (using
    /// `tokenIdentityImplementation()`).
    /// 5. Ensures this implementation address is configured (not `address(0)`), reverting with
    /// `IdentityImplementationNotSet` if not.
    /// 6. Performs a `delegatecall` to the `initialize` function of the `Identity` contract (which
    /// `SMARTTokenIdentityImplementation` inherits).
    ///    This `initialize(initialManagementKey)` call sets up the initial management key for this specific token
    /// identity instance
    ///    *within the storage context of this proxy*.
    ///    If this `delegatecall` fails, the proxy deployment reverts.
    /// @param systemAddress The address of the `ISMARTSystem` contract. This system contract provides the address of
    /// the `SMARTTokenIdentityImplementation` logic contract.
    /// @param accessManager The address of the `ISMARTTokenAccessManager` contract. This manager contract handles
    /// the access control for the token's identity.
    constructor(address systemAddress, address accessManager) {
        if (systemAddress == address(0) || !IERC165(systemAddress).supportsInterface(type(ISMARTSystem).interfaceId)) {
            revert InvalidSystemAddress();
        }
        _setSystem(ISMARTSystem(systemAddress));

        if (accessManager == address(0)) revert ZeroAddressNotAllowed();

        ISMARTSystem system_ = _getSystem();
        address implementation = system_.tokenIdentityImplementation(); // Fetches the token-specific identity impl.
        if (implementation == address(0)) revert IdentityImplementationNotSet();

        // Prepare the call data for delegatecalling Identity.initialize(initialManagementKey)
        // The selector is for the initialize function in the OnchainID `Identity` contract.
        bytes memory data = abi.encodeWithSelector(ISMARTTokenIdentity.initialize.selector, accessManager);

        // Perform the delegatecall to initialize the identity logic in the context of this proxy's storage.
        // slither-disable-next-line low-level-calls: Delegatecall is inherent and fundamental to proxy functionality.
        (bool success,) = implementation.delegatecall(data);

        // If the initialization (via delegatecall) failed, revert the proxy deployment.
        if (!success) revert InitializationFailed();
    }

    /// @notice Determines the address of the current logic/implementation contract for this token identity proxy.
    /// @dev This function is a core part of OpenZeppelin's `Proxy` contract functionality (EIP-1967).
    ///      It's called internally by the `Proxy` base contract before every external function call made to this proxy.
    ///      The `Proxy` then `delegatecall`s the user's request to the address returned by this function.
    ///      Here, it fetches the `tokenIdentityImplementation` address from the `ISMARTSystem` contract.
    ///      This allows the `ISMARTSystem` admin to upgrade the token identity logic for all `SMARTTokenIdentityProxy`
    /// instances.
    /// @return address The current address of the `SMARTTokenIdentityImplementation` contract.
    function _implementation() internal view override returns (address) {
        ISMARTSystem system_ = _getSystem();
        return system_.tokenIdentityImplementation(); // Uses the token-specific implementation getter
    }

    /// @notice Rejects any direct Ether (ETH) transfers to this proxy contract.
    /// @dev Proxy contracts for token identities typically do not need to hold Ether themselves.
    ///      The `payable` keyword is required for `receive()` to be valid, but the `revert` ensures no ETH is accepted,
    ///      preventing accidental locking of funds in the proxy.
    receive() external payable {
        revert ETHTransfersNotAllowed();
    }
}
