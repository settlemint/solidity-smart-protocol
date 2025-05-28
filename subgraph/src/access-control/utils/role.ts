import { ByteArray, Bytes, crypto } from "@graphprotocol/graph-ts";

class RoleConfig {
  _name: string;
  _bytes: Bytes;
  _hexString: string;
  _fieldName: string;

  constructor(name: string, fieldName: string) {
    this._name = name;
    if (name === "DEFAULT_ADMIN_ROLE") {
      this._hexString =
        "0x0000000000000000000000000000000000000000000000000000000000000000";
    } else {
      this._hexString = crypto
        .keccak256(ByteArray.fromUTF8(name))
        .toHexString();
    }
    this._bytes = Bytes.fromHexString(this._hexString);
    this._fieldName = fieldName;
  }

  get name(): string {
    return this._name;
  }

  get bytes(): Bytes {
    return this._bytes;
  }

  get hexString(): string {
    return this._hexString;
  }

  get fieldName(): string {
    return this._fieldName;
  }
}

export const Roles = [
  new RoleConfig("DEFAULT_ADMIN_ROLE", "admin"),
  new RoleConfig("REGISTRAR_ROLE", "registrar"),
  new RoleConfig("REGISTRAR_ADMIN_ROLE", "registrarAdmin"),
  new RoleConfig("REGISTRAR_GOVERNOR_ROLE", "registrarGovernor"),
  new RoleConfig("CLAIM_MANAGER_ROLE", "claimManager"),
  new RoleConfig("IDENTITY_ISSUER_ROLE", "identityIssuer"),
  new RoleConfig("TOKEN_IDENTITY_ISSUER_ROLE", "tokenIdentityIssuer"),
  new RoleConfig(
    "TOKEN_IDENTITY_ISSUER_ADMIN_ROLE",
    "tokenIdentityIssuerAdmin"
  ),
  new RoleConfig("TOKEN_DEPLOYER_ROLE", "tokenDeployer"),
  new RoleConfig("STORAGE_MODIFIER_ROLE", "storageModifier"),
  new RoleConfig("MANAGE_REGISTRIES_ROLE", "manageRegistries"),
  new RoleConfig("TOKEN_GOVERNANCE_ROLE", "tokenGovernance"),
  new RoleConfig("SUPPLY_MANAGEMENT_ROLE", "supplyManagement"),
  new RoleConfig("CUSTODIAN_ROLE", "custodian"),
  new RoleConfig("EMERGENCY_ROLE", "emergency"),
];

export function getRoleConfigFromBytes(bytes: Bytes): RoleConfig {
  const hexString = bytes.toHexString();
  let role: RoleConfig | null = null;
  for (let i = 0; i < Roles.length; i++) {
    if (Roles[i].hexString == hexString) {
      role = Roles[i];
      break;
    }
  }

  if (!role) {
    throw new Error(`Unconfigured role: ${hexString}`);
  }

  return role;
}
