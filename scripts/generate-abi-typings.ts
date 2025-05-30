import { mkdir } from "node:fs/promises";
import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

const BASE_PATH = join(process.cwd(), "artifacts", "contracts");
const OUTPUT_PATH = join(process.cwd(), "scripts", "hardhat", "abi");

export const ABI_PATHS = {
  // onboarding
  system: `${BASE_PATH}/system/ISMARTSystem.sol/ISMARTSystem.json`,
  compliance: `${BASE_PATH}/interface/ISMARTCompliance.sol/ISMARTCompliance.json`,
  identityRegistry: `${BASE_PATH}/interface/ISMARTIdentityRegistry.sol/ISMARTIdentityRegistry.json`,
  identityRegistryStorage: `${BASE_PATH}/interface/ERC-3643/IERC3643IdentityRegistryStorage.sol/IERC3643IdentityRegistryStorage.json`,
  trustedIssuersRegistry: `${BASE_PATH}/interface/ERC-3643/IERC3643TrustedIssuersRegistry.sol/IERC3643TrustedIssuersRegistry.json`,
  topicSchemeRegistry: `${BASE_PATH}/system/topic-scheme-registry/SMARTTopicSchemeRegistryImplementation.sol/SMARTTopicSchemeRegistryImplementation.json`,
  identityFactory: `${BASE_PATH}/system/identity-factory/ISMARTIdentityFactory.sol/ISMARTIdentityFactory.json`,
  bondFactory: `${BASE_PATH}/assets/bond/ISMARTBondFactory.sol/ISMARTBondFactory.json`,
  depositFactory: `${BASE_PATH}/assets/deposit/SMARTDepositFactoryImplementation.sol/SMARTDepositFactoryImplementation.json`,
  equityFactory: `${BASE_PATH}/assets/equity/ISMARTEquityFactory.sol/ISMARTEquityFactory.json`,
  fundFactory: `${BASE_PATH}/assets/fund/ISMARTFundFactory.sol/ISMARTFundFactory.json`,
  stablecoinFactory: `${BASE_PATH}/assets/stable-coin/ISMARTStableCoinFactory.sol/ISMARTStableCoinFactory.json`,
  // token
  accessManager: `${BASE_PATH}/extensions/access-managed/ISMARTTokenAccessManager.sol/ISMARTTokenAccessManager.json`,
  identity: `${BASE_PATH}/system/identity-factory/identities/SMARTIdentityImplementation.sol/SMARTIdentityImplementation.json`,
  tokenIdentity: `${BASE_PATH}/system/identity-factory/identities/SMARTTokenIdentityImplementation.sol/SMARTTokenIdentityImplementation.json`,
  // tokens
  deposit: `${BASE_PATH}/assets/deposit/SMARTDepositImplementation.sol/SMARTDepositImplementation.json`,
  equity: `${BASE_PATH}/assets/equity/ISMARTEquity.sol/ISMARTEquity.json`,
  fund: `${BASE_PATH}/assets/fund/ISMARTFund.sol/ISMARTFund.json`,
  stablecoin: `${BASE_PATH}/assets/stable-coin/ISMARTStableCoin.sol/ISMARTStableCoin.json`,
  bond: `${BASE_PATH}/assets/bond/ISMARTBond.sol/ISMARTBond.json`,
  // smart
  ismart: `${BASE_PATH}/interface/ISMART.sol/ISMART.json`,
  ismartBurnable: `${BASE_PATH}/extensions/burnable/ISMARTBurnable.sol/ISMARTBurnable.json`,
} as const;

export async function generateAbiTypings() {
  console.log("Generating abi typings...");
  await mkdir(OUTPUT_PATH, { recursive: true });
  for (const [abiName, value] of Object.entries(ABI_PATHS)) {
    const abi = await readFile(value, "utf-8");
    const parsed = JSON.parse(abi);
    await writeFile(
      join(OUTPUT_PATH, `${abiName}.ts`),
      `export const ${abiName}Abi = ${JSON.stringify(parsed.abi, undefined, 2)} as const;`,
    );
  }
  console.log("Abi typings generated successfully");
}
generateAbiTypings();
