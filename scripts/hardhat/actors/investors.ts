import hre from "hardhat";
import { type WalletClient, createWalletClient, custom } from "viem";
import type { LocalAccount } from "viem/accounts"; // viem signer type
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";

import { getViemChain } from "../utils/viem-chain";
import { AbstractActor } from "./abstract-actor";

/**
 * Class representing a claim issuer that can generate and sign claims
 */
class Investor extends AbstractActor {
	private readonly signer: LocalAccount;
	/**
	 * Create a new claim issuer
	 * @param name - The name of the investor
	 * @param privateKey - Optional private key for the signer. If not provided, a random one will be generated.
	 */
	constructor(name: string, privateKey?: `0x${string}`) {
		super(name);

		const pk = privateKey ?? generatePrivateKey();
		this.signer = privateKeyToAccount(pk);
		this._address = this.signer.address;
	}

	public async initialize(): Promise<void> {
		await super.initialize();
	}

	/**
	 * Get a viem WalletClient for this issuer's account.
	 * @returns A WalletClient instance.
	 * @example
	 * ```ts
	 * import { sepolia } from "viem/chains";
	 * import { http } from "viem";
	 * const issuer = new ClaimIssuer();
	 * const walletClient = issuer.getWalletClient({
	 *   chain: sepolia,
	 *   transport: http("https://rpc.sepolia.org")
	 * });
	 * ```
	 */
	public getWalletClient(): WalletClient {
		const viemChain = getViemChain();
		return createWalletClient({
			account: this.signer,
			chain: viemChain,
			transport: custom(hre.network.provider), // Use Hardhat's EIP-1193 provider
		});
	}
}

/**
 * A reusable instance of the ClaimIssuer with a consistent address
 */
export const investorA = new Investor("Investor A");
export const investorB = new Investor("Investor B");
