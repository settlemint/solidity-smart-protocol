import type { Abi } from "viem";
import { abi as bondAbiJson } from "../../../artifacts/contracts/assets/bond/ISMARTBond.sol/ISMARTBond.json";
// --- ABI Imports ---
import { abi as bondFactoryAbiJson } from "../../../artifacts/contracts/assets/bond/ISMARTBondFactory.sol/ISMARTBondFactory.json";
// import { abi as depositFactoryAbiJson } from "../../../out/ISMARTDepositFactory.sol/ISMARTDepositFactory.json";
import { abi as depositFactoryAbiJson } from "../../../artifacts/contracts/assets/deposit/SMARTDepositFactoryImplementation.sol/SMARTDepositFactoryImplementation.json";
import { abi as depositAbiJson } from "../../../artifacts/contracts/assets/deposit/SMARTDepositImplementation.sol/SMARTDepositImplementation.json";
import { abi as equityAbiJson } from "../../../artifacts/contracts/assets/equity/ISMARTEquity.sol/ISMARTEquity.json";
import { abi as equityFactoryAbiJson } from "../../../artifacts/contracts/assets/equity/ISMARTEquityFactory.sol/ISMARTEquityFactory.json";
import { abi as fundAbiJson } from "../../../artifacts/contracts/assets/fund/ISMARTFund.sol/ISMARTFund.json";
import { abi as fundFactoryAbiJson } from "../../../artifacts/contracts/assets/fund/ISMARTFundFactory.sol/ISMARTFundFactory.json";
import { abi as stablecoinAbiJson } from "../../../artifacts/contracts/assets/stable-coin/ISMARTStableCoin.sol/ISMARTStableCoin.json";
import { abi as stablecoinFactoryAbiJson } from "../../../artifacts/contracts/assets/stable-coin/ISMARTStableCoinFactory.sol/ISMARTStableCoinFactory.json";
import { abi as accessManagerAbiJson } from "../../../artifacts/contracts/extensions/access-managed/ISMARTTokenAccessManager.sol/ISMARTTokenAccessManager.json";
import { abi as identityRegistryStorageAbiJson } from "../../../artifacts/contracts/interface/ERC-3643/IERC3643IdentityRegistryStorage.sol/IERC3643IdentityRegistryStorage.json";
import { abi as trustedIssuersRegistryAbiJson } from "../../../artifacts/contracts/interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol/IERC3643TrustedIssuersRegistry.json";
import { abi as ismartAbiJson } from "../../../artifacts/contracts/interface/ISMART.sol/ISMART.json";
import { abi as complianceAbiJson } from "../../../artifacts/contracts/interface/ISMARTCompliance.sol/ISMARTCompliance.json";
import { abi as identityRegistryAbiJson } from "../../../artifacts/contracts/interface/ISMARTIdentityRegistry.sol/ISMARTIdentityRegistry.json";
import { abi as systemAbiJson } from "../../../artifacts/contracts/system/ISMARTSystem.sol/ISMARTSystem.json";
import { abi as identityFactoryAbiJson } from "../../../artifacts/contracts/system/identity-factory/ISMARTIdentityFactory.sol/ISMARTIdentityFactory.json";
import { abi as identityAbiJson } from "../../../artifacts/contracts/system/identity-factory/identities/SMARTIdentityImplementation.sol/SMARTIdentityImplementation.json";
import { abi as tokenIdentityAbiJson } from "../../../artifacts/contracts/system/identity-factory/identities/SMARTTokenIdentityImplementation.sol/SMARTTokenIdentityImplementation.json";

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
	// tokens
	ismart: asAbi(ismartAbiJson),
	deposit: asAbi(depositAbiJson),
	equity: asAbi(equityAbiJson),
	fund: asAbi(fundAbiJson),
	stablecoin: asAbi(stablecoinAbiJson),
	bond: asAbi(bondAbiJson),
} as const;
