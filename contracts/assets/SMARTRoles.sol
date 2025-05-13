// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

library SMARTRoles {
    // Role constants
    bytes32 public constant TOKEN_ADMIN_ROLE = keccak256("TOKEN_ADMIN_ROLE");

    bytes32 public constant COMPLIANCE_ADMIN_ROLE = keccak256("COMPLIANCE_ADMIN_ROLE");

    bytes32 public constant VERIFICATION_ADMIN_ROLE = keccak256("VERIFICATION_ADMIN_ROLE");

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE");

    bytes32 public constant FORCED_TRANSFER_ROLE = keccak256("FORCED_TRANSFER_ROLE");

    bytes32 public constant RECOVERY_ROLE = keccak256("RECOVERY_ROLE");

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
}
