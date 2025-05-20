// SPDX-License-Identifier: FSL-1.1-MIT
pragma solidity 0.8.28;

library SMARTRoles {
    // Matches the default admin role in OpenZeppelin's AccessControl.
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 public constant TOKEN_GOVERNANCE_ROLE = keccak256("TOKEN_GOVERNANCE_ROLE"); // TOKEN_ADMIN, VERIFICATION,
        // COMPLIANCE

    bytes32 public constant SUPPLY_MANAGEMENT_ROLE = keccak256("SUPPLY_MANAGEMENT_ROLE"); // MINT, BURN

    bytes32 public constant CUSTODIAN_ROLE = keccak256("CUSTODIAN_ROLE"); // FREEZE, FORCED_TRANSFER, RECOVERY

    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE"); // PAUSE, ERC20_RECOVERY

    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    bytes32 public constant TOKEN_REGISTRAR_ROLE = keccak256("TOKEN_REGISTRAR_ROLE");
    bytes32 public constant TOKEN_REGISTRAR_MANAGER_ROLE = keccak256("TOKEN_REGISTRAR_MANAGER_ROLE");
}
