import hre from "hardhat";
import {
	type Abi,
	type Address,
	type GetContractReturnType,
	type PublicClient,
	type WalletClient,
	createPublicClient,
	custom,
	getContract as getViemContract,
} from "viem";
import * as viemChains from "viem/chains";

import SMARTOnboardingModule from "../../ignition/modules/onboarding";

// --- ABI Imports ---
import { abi as identityRegistryStorageAbiJson } from "../../out/IERC3643IdentityRegistryStorage.sol/IERC3643IdentityRegistryStorage.json";
import { abi as trustedIssuersRegistryAbiJson } from "../../out/IERC3643TrustedIssuersRegistry.sol/IERC3643TrustedIssuersRegistry.json";
import { abi as bondFactoryAbiJson } from "../../out/ISMARTBondFactory.sol/ISMARTBondFactory.json";
import { abi as complianceAbiJson } from "../../out/ISMARTCompliance.sol/ISMARTCompliance.json";
import { abi as depositFactoryAbiJson } from "../../out/ISMARTDepositFactory.sol/ISMARTDepositFactory.json";
import { abi as equityFactoryAbiJson } from "../../out/ISMARTEquityFactory.sol/ISMARTEquityFactory.json";
import { abi as fundFactoryAbiJson } from "../../out/ISMARTFundFactory.sol/ISMARTFundFactory.json";
import { abi as identityFactoryAbiJson } from "../../out/ISMARTIdentityFactory.sol/ISMARTIdentityFactory.json";
import { abi as identityRegistryAbiJson } from "../../out/ISMARTIdentityRegistry.sol/ISMARTIdentityRegistry.json";
import { abi as stablecoinFactoryAbiJson } from "../../out/ISMARTStablecoinFactory.sol/ISMARTStablecoinFactory.json";
import { abi as systemAbiJson } from "../../out/ISMARTSystem.sol/ISMARTSystem.json";

// Helper function to ensure ABI is treated as `Abi` type
const asAbi = (abi: unknown): Abi => abi as Abi;

const contractAbis = {
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
};

// Helper type for Viem contract instances
type ViemContract<
	TAbi extends Abi,
	TClient extends PublicClient | { public: PublicClient; wallet: WalletClient },
> = GetContractReturnType<TAbi, TClient>;

/**
 * Defines the structure for the contracts deployed by SMARTOnboardingModule,
 * typed with Viem for read-only operations.
 */
export interface SMARTOnboardingContracts {
	system: ViemContract<typeof contractAbis.system, PublicClient>;
	compliance: ViemContract<typeof contractAbis.compliance, PublicClient>;
	identityRegistry: ViemContract<
		typeof contractAbis.identityRegistry,
		PublicClient
	>;
	identityRegistryStorage: ViemContract<
		typeof contractAbis.identityRegistryStorage,
		PublicClient
	>;
	trustedIssuersRegistry: ViemContract<
		typeof contractAbis.trustedIssuersRegistry,
		PublicClient
	>;
	identityFactory: ViemContract<
		typeof contractAbis.identityFactory,
		PublicClient
	>;
	bondFactory: ViemContract<typeof contractAbis.bondFactory, PublicClient>;
	depositFactory: ViemContract<
		typeof contractAbis.depositFactory,
		PublicClient
	>;
	equityFactory: ViemContract<typeof contractAbis.equityFactory, PublicClient>;
	fundFactory: ViemContract<typeof contractAbis.fundFactory, PublicClient>;
	stablecoinFactory: ViemContract<
		typeof contractAbis.stablecoinFactory,
		PublicClient
	>;
}

/**
 * Defines the structure for the contracts deployed by SMARTOnboardingModule,
 * typed with Viem for write operations (includes WalletClient).
 */
export type SMARTOnboardingContractsWithWallet = {
	system: ViemContract<
		typeof contractAbis.system,
		{ public: PublicClient; wallet: WalletClient }
	>;
	compliance: ViemContract<
		typeof contractAbis.compliance,
		{ public: PublicClient; wallet: WalletClient }
	>;
	identityRegistry: ViemContract<
		typeof contractAbis.identityRegistry,
		{ public: PublicClient; wallet: WalletClient }
	>;
	identityRegistryStorage: ViemContract<
		typeof contractAbis.identityRegistryStorage,
		{ public: PublicClient; wallet: WalletClient }
	>;
	trustedIssuersRegistry: ViemContract<
		typeof contractAbis.trustedIssuersRegistry,
		{ public: PublicClient; wallet: WalletClient }
	>;
	identityFactory: ViemContract<
		typeof contractAbis.identityFactory,
		{ public: PublicClient; wallet: WalletClient }
	>;
	bondFactory: ViemContract<
		typeof contractAbis.bondFactory,
		{ public: PublicClient; wallet: WalletClient }
	>;
	depositFactory: ViemContract<
		typeof contractAbis.depositFactory,
		{ public: PublicClient; wallet: WalletClient }
	>;
	equityFactory: ViemContract<
		typeof contractAbis.equityFactory,
		{ public: PublicClient; wallet: WalletClient }
	>;
	fundFactory: ViemContract<
		typeof contractAbis.fundFactory,
		{ public: PublicClient; wallet: WalletClient }
	>;
	stablecoinFactory: ViemContract<
		typeof contractAbis.stablecoinFactory,
		{ public: PublicClient; wallet: WalletClient }
	>;
};

// Type for storing deployed contract addresses
type DeployedContractAddresses = {
	[K in keyof SMARTOnboardingContracts]: { address: Address };
};

// Helper to get Viem chain object from chainId
function getViemChain(chainId: number): viemChains.Chain {
	for (const chainKey in viemChains) {
		// biome-ignore lint/suspicious/noExplicitAny: Iterating over module exports
		const chain = (viemChains as any)[chainKey] as viemChains.Chain;
		if (chain.id === chainId) {
			return chain;
		}
	}
	console.warn(
		`Viem chain definition not found for chainId ${chainId}. Defaulting to Hardhat local chain.`,
	);
	return viemChains.hardhat; // Fallback
}

/**
 * A singleton class to manage the deployment and access of SMART Protocol contracts.
 */
export class SmartProtocolDeployer {
	private static instance: SmartProtocolDeployer | null = null;
	private _deployedContractAddresses: DeployedContractAddresses | undefined;
	private _publicClient: PublicClient | undefined;

	public constructor() {
		this._deployedContractAddresses = undefined;
	}

	/**
	 * Deploys the SMARTOnboardingModule contracts using Hardhat Ignition.
	 * Stores the Viem-typed contract instances internally.
	 * This method should only be called once.
	 */
	public async setUp(): Promise<void> {
		if (this._deployedContractAddresses) {
			console.warn(
				"SMARTOnboardingModule has already been deployed. Skipping setup.",
			);
			return;
		}
		console.log("Starting deployment of SMARTOnboardingModule...");
		try {
			// 1. Deploy contracts and get their addresses
			const deploymentAddresses = (await hre.ignition.deploy(
				SMARTOnboardingModule,
			)) as DeployedContractAddresses;

			// 2. Create Viem PublicClient
			const chainId = hre.network.config?.chainId;
			if (typeof chainId !== "number") {
				throw new Error("Chain ID not found in Hardhat network configuration.");
			}
			const viemChain = getViemChain(chainId);
			const publicClient = createPublicClient({
				chain: viemChain,
				transport: custom(hre.network.provider), // Use Hardhat's EIP-1193 provider
			});
			this._publicClient = publicClient; // Store the public client

			// 3. Store deployed addresses
			this._deployedContractAddresses = deploymentAddresses;

			console.log(
				"SMARTOnboardingModule deployed successfully! Contract addresses stored.",
			);
			if (this._deployedContractAddresses) {
				console.log("Deployed Contracts Addresses:");
				for (const [name, contractInfo] of Object.entries(
					this._deployedContractAddresses,
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

	// Overload signatures for getContract
	private getContract<K extends keyof SMARTOnboardingContracts>(
		contractName: K,
	): ViemContract<(typeof contractAbis)[K], PublicClient>;
	private getContract<K extends keyof SMARTOnboardingContracts>(
		contractName: K,
		walletClient: WalletClient,
	): ViemContract<
		(typeof contractAbis)[K],
		{ public: PublicClient; wallet: WalletClient }
	>;

	// Implementation of getContract
	private getContract<K extends keyof SMARTOnboardingContracts>(
		contractName: K,
		walletClient?: WalletClient,
	): ViemContract<
		(typeof contractAbis)[K],
		PublicClient | { public: PublicClient; wallet: WalletClient }
	> {
		if (!this._deployedContractAddresses) {
			throw new Error(
				"Contracts not deployed. Call setUp() before accessing contracts.",
			);
		}
		if (!this._publicClient) {
			throw new Error(
				"Public client not initialized. Call setUp() before accessing contracts.",
			);
		}
		const contractInfo = this._deployedContractAddresses[contractName];
		if (!contractInfo?.address) {
			throw new Error(
				`Contract "${String(
					contractName,
				)}" address not found in deployment results.`,
			);
		}
		const abi = contractAbis[contractName];
		if (!abi) {
			throw new Error(`ABI for contract "${String(contractName)}" not found.`);
		}

		const clientConfig = walletClient
			? { public: this._publicClient, wallet: walletClient }
			: this._publicClient;

		return getViemContract({
			address: contractInfo.address,
			abi: abi,
			client: clientConfig,
		}) as ViemContract<
			(typeof contractAbis)[K],
			PublicClient | { public: PublicClient; wallet: WalletClient }
		>; // Cast needed for the unified implementation signature
	}

	// --- Unified Contract Accessor Methods ---

	public getSystemContract(): SMARTOnboardingContracts["system"];
	public getSystemContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["system"];
	public getSystemContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["system"]
		| SMARTOnboardingContractsWithWallet["system"] {
		if (walletClient) {
			return this.getContract("system", walletClient);
		}
		return this.getContract("system");
	}

	public getComplianceContract(): SMARTOnboardingContracts["compliance"];
	public getComplianceContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["compliance"];
	public getComplianceContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["compliance"]
		| SMARTOnboardingContractsWithWallet["compliance"] {
		if (walletClient) {
			return this.getContract("compliance", walletClient);
		}
		return this.getContract("compliance");
	}

	public getIdentityRegistryContract(): SMARTOnboardingContracts["identityRegistry"];
	public getIdentityRegistryContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["identityRegistry"];
	public getIdentityRegistryContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["identityRegistry"]
		| SMARTOnboardingContractsWithWallet["identityRegistry"] {
		if (walletClient) {
			return this.getContract("identityRegistry", walletClient);
		}
		return this.getContract("identityRegistry");
	}

	public getIdentityRegistryStorageContract(): SMARTOnboardingContracts["identityRegistryStorage"];
	public getIdentityRegistryStorageContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["identityRegistryStorage"];
	public getIdentityRegistryStorageContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["identityRegistryStorage"]
		| SMARTOnboardingContractsWithWallet["identityRegistryStorage"] {
		if (walletClient) {
			return this.getContract("identityRegistryStorage", walletClient);
		}
		return this.getContract("identityRegistryStorage");
	}

	public getTrustedIssuersRegistryContract(): SMARTOnboardingContracts["trustedIssuersRegistry"];
	public getTrustedIssuersRegistryContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["trustedIssuersRegistry"];
	public getTrustedIssuersRegistryContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["trustedIssuersRegistry"]
		| SMARTOnboardingContractsWithWallet["trustedIssuersRegistry"] {
		if (walletClient) {
			return this.getContract("trustedIssuersRegistry", walletClient);
		}
		return this.getContract("trustedIssuersRegistry");
	}

	public getIdentityFactoryContract(): SMARTOnboardingContracts["identityFactory"];
	public getIdentityFactoryContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["identityFactory"];
	public getIdentityFactoryContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["identityFactory"]
		| SMARTOnboardingContractsWithWallet["identityFactory"] {
		if (walletClient) {
			return this.getContract("identityFactory", walletClient);
		}
		return this.getContract("identityFactory");
	}

	public getBondFactoryContract(): SMARTOnboardingContracts["bondFactory"];
	public getBondFactoryContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["bondFactory"];
	public getBondFactoryContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["bondFactory"]
		| SMARTOnboardingContractsWithWallet["bondFactory"] {
		if (walletClient) {
			return this.getContract("bondFactory", walletClient);
		}
		return this.getContract("bondFactory");
	}

	public getDepositFactoryContract(): SMARTOnboardingContracts["depositFactory"];
	public getDepositFactoryContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["depositFactory"];
	public getDepositFactoryContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["depositFactory"]
		| SMARTOnboardingContractsWithWallet["depositFactory"] {
		if (walletClient) {
			return this.getContract("depositFactory", walletClient);
		}
		return this.getContract("depositFactory");
	}

	public getEquityFactoryContract(): SMARTOnboardingContracts["equityFactory"];
	public getEquityFactoryContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["equityFactory"];
	public getEquityFactoryContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["equityFactory"]
		| SMARTOnboardingContractsWithWallet["equityFactory"] {
		if (walletClient) {
			return this.getContract("equityFactory", walletClient);
		}
		return this.getContract("equityFactory");
	}

	public getFundFactoryContract(): SMARTOnboardingContracts["fundFactory"];
	public getFundFactoryContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["fundFactory"];
	public getFundFactoryContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["fundFactory"]
		| SMARTOnboardingContractsWithWallet["fundFactory"] {
		if (walletClient) {
			return this.getContract("fundFactory", walletClient);
		}
		return this.getContract("fundFactory");
	}

	public getStablecoinFactoryContract(): SMARTOnboardingContracts["stablecoinFactory"];
	public getStablecoinFactoryContract(
		walletClient: WalletClient,
	): SMARTOnboardingContractsWithWallet["stablecoinFactory"];
	public getStablecoinFactoryContract(
		walletClient?: WalletClient,
	):
		| SMARTOnboardingContracts["stablecoinFactory"]
		| SMARTOnboardingContractsWithWallet["stablecoinFactory"] {
		if (walletClient) {
			return this.getContract("stablecoinFactory", walletClient);
		}
		return this.getContract("stablecoinFactory");
	}
}

export const smartProtocolDeployer = new SmartProtocolDeployer();
