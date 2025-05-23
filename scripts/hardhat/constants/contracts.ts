import type { Abi } from "viem";
// --- ABI Imports ---
import { abi as identityRegistryStorageAbiJson } from "../../../out/IERC3643IdentityRegistryStorage.sol/IERC3643IdentityRegistryStorage.json";
import { abi as trustedIssuersRegistryAbiJson } from "../../../out/IERC3643TrustedIssuersRegistry.sol/IERC3643TrustedIssuersRegistry.json";
import { abi as bondFactoryAbiJson } from "../../../out/ISMARTBondFactory.sol/ISMARTBondFactory.json";
import { abi as complianceAbiJson } from "../../../out/ISMARTCompliance.sol/ISMARTCompliance.json";
import { abi as depositFactoryAbiJson } from "../../../out/ISMARTDepositFactory.sol/ISMARTDepositFactory.json";
import { abi as equityFactoryAbiJson } from "../../../out/ISMARTEquityFactory.sol/ISMARTEquityFactory.json";
import { abi as fundFactoryAbiJson } from "../../../out/ISMARTFundFactory.sol/ISMARTFundFactory.json";
import { abi as identityAbiJson } from "../../../out/ISMARTIdentity.sol/ISMARTIdentity.json";
import { abi as identityFactoryAbiJson } from "../../../out/ISMARTIdentityFactory.sol/ISMARTIdentityFactory.json";
import { abi as identityRegistryAbiJson } from "../../../out/ISMARTIdentityRegistry.sol/ISMARTIdentityRegistry.json";
import { abi as stablecoinFactoryAbiJson } from "../../../out/ISMARTStablecoinFactory.sol/ISMARTStablecoinFactory.json";
import { abi as systemAbiJson } from "../../../out/ISMARTSystem.sol/ISMARTSystem.json";
import { abi as accessManagerAbiJson } from "../../../out/ISMARTTokenAccessManager.sol/ISMARTTokenAccessManager.json";
import { abi as tokenIdentityAbiJson } from "../../../out/ISMARTTokenIdentity.sol/ISMARTTokenIdentity.json";
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
	identity: asAbi(identityAbiJson),
	tokenIdentity: asAbi(tokenIdentityAbiJson),
} as const;
