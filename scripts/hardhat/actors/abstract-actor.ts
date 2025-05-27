import {
	type Abi,
	type Address,
	type GetContractReturnType,
	type Hex,
	type PublicClient,
	type WalletClient,
	encodeAbiParameters,
	formatEther,
	getContract as getViemContract,
	keccak256,
	parseAbiParameters,
} from "viem";
import { SMARTContracts } from "../constants/contracts";
import { smartProtocolDeployer } from "../deployer";
import { getPublicClient } from "../utils/public-client";
import { waitForEvent } from "../utils/wait-for-event";

/**
 * Abstract base class for actors interacting with the blockchain.
 * An actor typically represents a user or an automated agent with its own wallet (Signer).
 * It requires HardhatRuntimeEnvironment for accessing ethers and contract artifacts.
 */
export abstract class AbstractActor {
	protected initialized = false;

	protected _address: Address | undefined;
	protected _identityPromise: Promise<`0x${string}`> | undefined;
	protected _identity: `0x${string}` | undefined;

	public readonly name: string;

	constructor(name: string) {
		this.name = name;
	}
	/**
	 * Abstract method to be implemented by subclasses.
	 * It should retrieve or create an ethers.js Signer instance representing the actor's wallet.
	 * @returns A Promise that resolves to an ethers Signer.
	 */
	abstract getWalletClient(): WalletClient;

	/**
	 * Initializes the actor by fetching and storing the wallet client (Signer).
	 * This method should typically be called once before any blockchain interactions.
	 * Subclasses can override this to add more specific initialization logic,
	 * ensuring they call `super.initialize()` if they override it.
	 * @throws Error if the wallet client cannot be initialized.
	 */
	async initialize(): Promise<void> {
		console.log(`[${this.name}] Address: ${this.address}`);

		this.initialized = true;
	}

	/**
	 * Get the address of the claim issuer
	 */
	get address(): Address {
		if (!this._address) {
			throw new Error("Address not initialized");
		}
		return this._address;
	}

	/**
	 * Ensures the signer is initialized, calling `initialize()` if necessary.
	 * @throws Error if the signer is not initialized after attempting to initialize.
	 */
	protected async ensureSignerInitialized(): Promise<void> {
		if (!this.initialized) {
			await this.initialize();
		}
	}

	async getIdentity(): Promise<`0x${string}`> {
		if (this._identityPromise) {
			return this._identityPromise;
		}

		this._identityPromise = new Promise((resolve, reject) => {
			(async () => {
				try {
					const identityFactory =
						smartProtocolDeployer.getIdentityFactoryContract();
					const transactionHash: Hex =
						await identityFactory.write.createIdentity([this.address, []]);

					console.log(`[${this.name}] transactionHash: ${transactionHash}`);
					const { identity } = (await waitForEvent({
						transactionHash,
						contract: identityFactory,
						eventName: "IdentityCreated",
					})) as unknown as { identity: `0x${string}` };

					this._identity = identity;

					console.log(`[${this.name}] identity: ${identity}`);

					const contract = this.getContractInstance({
						address: identity,
						abi: SMARTContracts.identity,
					});

					const hashedKey = keccak256(
						encodeAbiParameters(parseAbiParameters("address"), [this.address]),
					);
					const keyHasPurpose = await contract.read.keyHasPurpose([
						hashedKey,
						1,
					]);

					console.log(`[${this.name}] keyHasPurpose: ${keyHasPurpose}`);

					resolve(identity);
				} catch (error) {
					reject(error);
				}
			})();
		});

		return this._identityPromise;
	}

	/**
	 * Creates a Viem contract instance.
	 * For zero gas, pass { gas: 0n } as the second argument to write calls.
	 * Set useGasEstimation to true for standard gas estimation.
	 *
	 * @template TAbi - The ABI of the contract.
	 * @param {Object} params - The parameters for creating the contract instance.
	 * @param {Address} params.address - The address of the contract.
	 * @param {TAbi} params.abi - The ABI of the contract.
	 * @param {boolean} params.useGasEstimation - Whether to use gas estimation instead of zero gas (default: false).
	 * @returns {GetContractReturnType<TAbi, { public: PublicClient; wallet: WalletClient }>} The Viem contract instance.
	 */
	getContractInstance<TAbi extends Abi>({
		address,
		abi,
		useGasEstimation = false,
	}: {
		address: Address;
		abi: TAbi;
		useGasEstimation?: boolean;
	}): GetContractReturnType<
		TAbi,
		{ public: PublicClient; wallet: WalletClient }
	> {
		const walletClient = this.getWalletClient();

		// Create and return the base contract instance
		// Note: For zero gas, manually pass { gas: 0n } to write calls
		return getViemContract({
			address,
			abi,
			client: { public: getPublicClient(), wallet: walletClient },
		});
	}

	async getBalance() {
		const publicClient = getPublicClient();
		const ethBalance = await publicClient.getBalance({
			address: this.address,
		});
		return ethBalance;
	}

	async printBalance() {
		const ethBalance = await this.getBalance();
		console.log(`[${this.name}] ETH Balance: ${formatEther(ethBalance)} ETH`);
	}
}
