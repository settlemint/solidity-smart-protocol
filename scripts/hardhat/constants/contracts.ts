import type { Abi } from "viem";
// --- ABI Imports ---
import { abi as bondFactoryAbiJson } from "../../../artifacts/contracts/assets/bond/ISMARTBondFactory.sol/ISMARTBondFactory.json";
import { abi as depositFactoryAbiJson } from "../../../artifacts/contracts/assets/deposit/ISMARTDepositFactory.sol/ISMARTDepositFactory.json";
import { abi as equityFactoryAbiJson } from "../../../artifacts/contracts/assets/equity/ISMARTEquityFactory.sol/ISMARTEquityFactory.json";
import { abi as fundFactoryAbiJson } from "../../../artifacts/contracts/assets/fund/ISMARTFundFactory.sol/ISMARTFundFactory.json";
import { abi as stablecoinFactoryAbiJson } from "../../../artifacts/contracts/assets/stable-coin/ISMARTStableCoinFactory.sol/ISMARTStableCoinFactory.json";
import { abi as accessManagerAbiJson } from "../../../artifacts/contracts/extensions/access-managed/ISMARTTokenAccessManager.sol/ISMARTTokenAccessManager.json";
import { abi as identityRegistryStorageAbiJson } from "../../../artifacts/contracts/interface/ERC-3643/IERC3643IdentityRegistryStorage.sol/IERC3643IdentityRegistryStorage.json";
import { abi as trustedIssuersRegistryAbiJson } from "../../../artifacts/contracts/interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol/IERC3643TrustedIssuersRegistry.json";
import { abi as complianceAbiJson } from "../../../artifacts/contracts/interface/ISMARTCompliance.sol/ISMARTCompliance.json";
import { abi as identityRegistryAbiJson } from "../../../artifacts/contracts/interface/ISMARTIdentityRegistry.sol/ISMARTIdentityRegistry.json";
import { abi as tokenIdentityAbiJson } from "../../../artifacts/contracts/system/identity-factory/identities/ISMARTTokenIdentity.sol/ISMARTTokenIdentity.json";
import { abi as identityFactoryAbiJson } from "../../../artifacts/contracts/system/identity-factory/ISMARTIdentityFactory.sol/ISMARTIdentityFactory.json";
import { abi as systemAbiJson } from "../../../artifacts/contracts/system/ISMARTSystem.sol/ISMARTSystem.json";

const asAbi = (abi: unknown): Abi => abi as Abi;

export const SMARTContracts = {
  // onboarding
  system: asAbi(systemAbiJson),
  compliance: asAbi(complianceAbiJson),
  identityRegistry: asAbi(identityRegistryAbiJson),
  identityRegistryStorage: asAbi(identityRegistryStorageAbiJson),
  trustedIssuersRegistry: asAbi(trustedIssuersRegistryAbiJson),
  identityFactory: asAbi(identityFactoryAbiJson),
  bondFactory: asAbi(bondFactoryAbiJson),
  depositFactory: asAbi(depositFactoryAbiJson),
  equityFactory: asAbi(equityFactoryAbiJson),
  fundFactory: asAbi(fundFactoryAbiJson),
  stablecoinFactory: asAbi(stablecoinFactoryAbiJson),
  // token
  accessManager: asAbi(accessManagerAbiJson),
  tokenIdentity: asAbi(tokenIdentityAbiJson),
} as const;
