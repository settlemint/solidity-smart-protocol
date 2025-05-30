import { type Hex, keccak256, toBytes } from "viem";

const defaultAdminRole: Hex =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

// System Roles (from SMARTSystemRoles.sol)
const registrarRole = keccak256(toBytes("REGISTRAR_ROLE"));
const claimManagerRole = keccak256(toBytes("CLAIM_MANAGER_ROLE"));
const identityIssuerRole = keccak256(toBytes("IDENTITY_ISSUER_ROLE"));
const tokenIdentityIssuerRole = keccak256(
  toBytes("TOKEN_IDENTITY_ISSUER_ROLE"),
);
const tokenIdentityIssuerAdminRole = keccak256(
  toBytes("TOKEN_IDENTITY_ISSUER_ADMIN_ROLE"),
);
const tokenDeployerRole = keccak256(toBytes("TOKEN_DEPLOYER_ROLE"));
const storageModifierRole = keccak256(toBytes("STORAGE_MODIFIER_ROLE"));
const manageRegistriesRole = keccak256(toBytes("MANAGE_REGISTRIES_ROLE"));

// Asset Roles (from SMARTRoles.sol)
const tokenGovernanceRole = keccak256(toBytes("TOKEN_GOVERNANCE_ROLE"));
const supplyManagementRole = keccak256(toBytes("SUPPLY_MANAGEMENT_ROLE"));
const custodianRole = keccak256(toBytes("CUSTODIAN_ROLE"));
const emergencyRole = keccak256(toBytes("EMERGENCY_ROLE"));

export const SMARTRoles = {
  defaultAdminRole,
  // System Roles
  registrarRole,
  registrarAdminRole,
  registrarGovernorRole,
  claimManagerRole,
  identityIssuerRole,
  tokenIdentityIssuerRole,
  tokenIdentityIssuerAdminRole,
  tokenDeployerRole,
  storageModifierRole,
  manageRegistriesRole,
  // Asset Roles
  tokenGovernanceRole,
  supplyManagementRole,
  custodianRole,
  emergencyRole,
} as const; // Using 'as const' for stricter typing if preferred
