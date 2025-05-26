import {
	type Abi,
	type Address,
	type GetContractReturnType,
	type Hex,
	type PublicClient,
	type WalletClient,
	getContract as getViemContract,
} from "viem";
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
	protected _identity: `0x${string}` | undefined;

	protected readonly name: string;

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
		if (this._identity) {
			return this._identity;
		}

		const identityFactory = smartProtocolDeployer.getIdentityFactoryContract();
		const transactionHash: Hex = await identityFactory.write.createIdentity([
			this.address,
			[],
		]);

		const { identity } = (await waitForEvent({
			transactionHash,
			contract: identityFactory,
			eventName: "IdentityCreated",
		})) as unknown as { identity: `0x${string}` };

		this._identity = identity;

		console.log(`[${this.name}] identity: ${identity}`);

		return identity;
	}

	/**
	 * Creates a Viem contract instance.
	 *
	 * @template TAbi - The ABI of the contract.
	 * @param {Object} params - The parameters for creating the contract instance.
	 * @param {Address} params.address - The address of the contract.
	 * @param {TAbi} params.abi - The ABI of the contract.
	 * @param {PublicClient} params.publicClient - The Viem PublicClient.
	 * @returns {GetContractReturnType<TAbi, { public: PublicClient; wallet: WalletClient }>} The Viem contract instance.
	 */
	getContractInstance<TAbi extends Abi>({
		address,
		abi,
	}: {
		address: Address;
		abi: TAbi;
	}): GetContractReturnType<
		TAbi,
		{ public: PublicClient; wallet: WalletClient }
	> {
		return getViemContract({
			address,
			abi,
			client: { public: getPublicClient(), wallet: this.getWalletClient() },
		});
	}
}
