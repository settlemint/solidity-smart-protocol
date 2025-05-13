// // SPDX-License-Identifier: FSL-1.1-MIT
// pragma solidity ^0.8.28;

// // openzeppelin imports
// import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

// // SMART imports
// import { SMARTExtensionAccessControlAuthorization } from "../common/SMARTExtensionAccessControlAuthorization.sol";

// // Internal implementation imports
// import { _SMARTCustodianAuthorizationHooks } from "./internal/_SMARTCustodianAuthorizationHooks.sol";

// /// @title Access Control Authorization for SMART Custodian Extension
// /// @notice Implements authorization logic for the SMART Custodian features using OpenZeppelin's AccessControl.
// /// @dev Defines specific roles (FREEZER_ROLE, FORCED_TRANSFER_ROLE, RECOVERY_ROLE)
// ///      and implements the authorization hooks from `_SMARTCustodianAuthorizationHooks` to enforce these roles.
// ///      Compatible with both standard and upgradeable AccessControl implementations.
// abstract contract SMARTCustodianAccessControlAuthorization is
//     _SMARTCustodianAuthorizationHooks,
//     SMARTExtensionAccessControlAuthorization
// {
//     // --- Roles ---
//     /// @notice Role required to freeze/unfreeze addresses and partial token amounts.
//     bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE");
//     /// @notice Role required to execute forced transfers.
//     bytes32 public constant FORCED_TRANSFER_ROLE = keccak256("FORCED_TRANSFER_ROLE");
//     /// @notice Role required to perform address recovery.
//     bytes32 public constant RECOVERY_ROLE = keccak256("RECOVERY_ROLE");

//     // --- Authorization Hooks Implementation ---
//     /// @dev Authorizes freezing/unfreezing an address.
//     ///      Checks if the `_msgSender()` has the `FREEZER_ROLE`.
//     /// @inheritdoc _SMARTCustodianAuthorizationHooks
//     function _authorizeFreezeAddress() internal view virtual override {
//         address sender = _msgSender();
//         if (!hasRole(FREEZER_ROLE, sender)) {
//             revert IAccessControl.AccessControlUnauthorizedAccount(sender, FREEZER_ROLE);
//         }
//     }

//     /// @dev Authorizes freezing/unfreezing partial token amounts.
//     ///      Checks if the `_msgSender()` has the `FREEZER_ROLE`.
//     /// @inheritdoc _SMARTCustodianAuthorizationHooks
//     function _authorizeFreezePartialTokens() internal view virtual override {
//         address sender = _msgSender();
//         if (!hasRole(FREEZER_ROLE, sender)) {
//             revert IAccessControl.AccessControlUnauthorizedAccount(sender, FREEZER_ROLE);
//         }
//     }

//     /// @dev Authorizes executing a forced transfer.
//     ///      Checks if the `_msgSender()` has the `FORCED_TRANSFER_ROLE`.
//     /// @inheritdoc _SMARTCustodianAuthorizationHooks
//     function _authorizeForcedTransfer() internal view virtual override {
//         address sender = _msgSender();
//         if (!hasRole(FORCED_TRANSFER_ROLE, sender)) {
//             revert IAccessControl.AccessControlUnauthorizedAccount(sender, FORCED_TRANSFER_ROLE);
//         }
//     }

//     /// @dev Authorizes performing address recovery.
//     ///      Checks if the `_msgSender()` has the `RECOVERY_ROLE`.
//     /// @inheritdoc _SMARTCustodianAuthorizationHooks
//     function _authorizeRecoveryAddress() internal view virtual override {
//         address sender = _msgSender();
//         if (!hasRole(RECOVERY_ROLE, sender)) {
//             revert IAccessControl.AccessControlUnauthorizedAccount(sender, RECOVERY_ROLE);
//         }
//     }
// }
