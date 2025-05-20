// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

library SMARTRoles {
    // Role constants
    bytes32 public constant TOKEN_GOVERNANCE_ROLE = keccak256("TOKEN_GOVERNANCE_ROLE"); // TOKEN_ADMIN, VERIFICATION,
        // COMPLIANCE

    bytes32 public constant SUPPLY_MANAGEMENT_ROLE = keccak256("SUPPLY_MANAGEMENT_ROLE"); // MINT, BURN

    bytes32 public constant CUSTODIAN_ROLE = keccak256("CUSTODIAN_ROLE"); // FREEZE, FORCED_TRANSFER, RECOVERY

    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE"); // PAUSE, ERC20_RECOVERY

    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
}
