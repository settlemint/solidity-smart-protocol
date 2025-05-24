import hre from "hardhat";
import type {
  Abi,
  Address,
  GetContractReturnType,
  PublicClient,
  WalletClient,
} from "viem";

import SMARTOnboardingModule from "../../ignition/modules/onboarding";
import { SMARTContracts } from "./constants/contracts";

import { getDefaultWalletClient } from "./utils/default-signer";
import { getContractInstance } from "./utils/get-contract";
// --- Utility Imports ---
import { getPublicClient } from "./utils/public-client";

// Type for the keys of CONTRACT_METADATA, e.g., "system" | "compliance" | ...
type ContractName = keyof Pick<
  typeof SMARTContracts,
  | "system"
  | "compliance"
  | "identityRegistry"
  | "identityRegistryStorage"
  | "trustedIssuersRegistry"
  | "identityFactory"
  | "bondFactory"
  | "depositFactory"
  | "equityFactory"
  | "fundFactory"
  | "stablecoinFactory"
>;

// Helper type for Viem contract instances
export type ViemContract<
  TAbi extends Abi,
  TClient extends { public: PublicClient; wallet: WalletClient }
> = GetContractReturnType<TAbi, TClient>;

/**
 * Defines the structure for the contracts deployed by SMARTOnboardingModule,
 * typed with Viem for write operations (includes WalletClient).
 */
export type SMARTOnboardingContracts = {
  [K in ContractName]: ViemContract<
    (typeof SMARTContracts)[K], // Access ABI by key
    { public: PublicClient; wallet: WalletClient }
  >;
};

// Type for storing deployed contract addresses
type DeployedContractAddresses = {
  [K in ContractName]: { address: Address };
};

/**
 * A singleton class to manage the deployment and access of SMART Protocol contracts.
 */
export class SmartProtocolDeployer {
  private _deployedContractAddresses: DeployedContractAddresses | undefined;
  private _defaultWalletClient: WalletClient | undefined;

  public constructor() {
    this._deployedContractAddresses = undefined;
    this._defaultWalletClient = undefined;
  }

  /**
   * Deploys the SMARTOnboardingModule contracts using Hardhat Ignition.
   * Stores the Viem-typed contract instances internally.
   * This method should only be called once.
   */
  public async setUp(): Promise<void> {
    if (this._deployedContractAddresses) {
      console.warn(
        "SMARTOnboardingModule has already been deployed. Skipping setup."
      );
      return;
    }
    console.log("Starting deployment of SMARTOnboardingModule...");
    try {
      // 1. Deploy contracts and get their addresses
      const deploymentAddresses = (await hre.ignition.deploy(
        SMARTOnboardingModule
      )) as DeployedContractAddresses;

      // 2. Initialize the default wallet client
      this._defaultWalletClient = await getDefaultWalletClient();

      // 3. Store deployed addresses
      this._deployedContractAddresses = deploymentAddresses;

      console.log(
        "SMARTOnboardingModule deployed successfully! Contract addresses and default signer initialized."
      );
      if (this._deployedContractAddresses) {
        console.log("Deployed Contracts Addresses:");
        for (const [name, contractInfo] of Object.entries(
          this._deployedContractAddresses
        )) {
          if (contractInfo && typeof contractInfo.address === "string") {
            console.log(`  ${name}: ${contractInfo.address}`);
          }
        }
      }
    } catch (error) {
      console.error("Failed to deploy SMARTOnboardingModule:", error);
      throw error; // Re-throw the error to indicate failure
    }
  }

  private getContract<K extends ContractName>(
    // Use ContractName here
    contractName: K,
    explicitWalletClient?: WalletClient
  ): ViemContract<
    (typeof SMARTContracts)[K],
    { public: PublicClient; wallet: WalletClient }
  > {
    if (!this._deployedContractAddresses) {
      throw new Error(
        "Contracts not deployed. Call setUp() before accessing contracts."
      );
    }

    const contractInfo = this._deployedContractAddresses[contractName];
    if (!contractInfo?.address) {
      throw new Error(
        `Contract "${String(
          contractName
        )}" address not found in deployment results.`
      );
    }

    const walletToUse = explicitWalletClient || this._defaultWalletClient;

    if (!walletToUse) {
      throw new Error(
        "Wallet client could not be determined. Ensure SMARTOnboardingModule is set up correctly or provide an explicit wallet client."
      );
    }

    return getContractInstance({
      address: contractInfo.address,
      abi: SMARTContracts[contractName],
      walletClient: walletToUse,
    }) as ViemContract<
      (typeof SMARTContracts)[K],
      { public: PublicClient; wallet: WalletClient }
    >;
  }

  // --- Unified Contract Accessor Methods ---

  public getSystemContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["system"] {
    return this.getContract("system", walletClient);
  }

  public getComplianceContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["compliance"] {
    return this.getContract("compliance", walletClient);
  }

  public getIdentityRegistryContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["identityRegistry"] {
    return this.getContract("identityRegistry", walletClient);
  }

  public getIdentityRegistryStorageContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["identityRegistryStorage"] {
    return this.getContract("identityRegistryStorage", walletClient);
  }

  public getTrustedIssuersRegistryContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["trustedIssuersRegistry"] {
    return this.getContract("trustedIssuersRegistry", walletClient);
  }

  public getIdentityFactoryContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["identityFactory"] {
    return this.getContract("identityFactory", walletClient);
  }

  public getBondFactoryContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["bondFactory"] {
    return this.getContract("bondFactory", walletClient);
  }

  public getDepositFactoryContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["depositFactory"] {
    return this.getContract("depositFactory", walletClient);
  }

  public getEquityFactoryContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["equityFactory"] {
    return this.getContract("equityFactory", walletClient);
  }

  public getFundFactoryContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["fundFactory"] {
    return this.getContract("fundFactory", walletClient);
  }

  public getStablecoinFactoryContract(
    walletClient?: WalletClient
  ): SMARTOnboardingContracts["stablecoinFactory"] {
    return this.getContract("stablecoinFactory", walletClient);
  }
}

export const smartProtocolDeployer = new SmartProtocolDeployer();
