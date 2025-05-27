import hre from "hardhat";
import type { WalletClient } from "viem";
import { AbstractActor } from "./abstract-actor";

/**
 * Class representing a claim issuer that can generate and sign claims
 */
class Investor extends AbstractActor {
	private accountIndex: number;
	private walletClient: WalletClient | null = null;
	/**
	 * Create a new claim issuer
	 * @param name - The name of the investor
	 * @param privateKey - Optional private key for the signer. If not provided, a random one will be generated.
	 */
	constructor(name: string, accountIndex: number) {
		super(name);
		this.accountIndex = accountIndex;
	}

	public async initialize(): Promise<void> {
		const wallets = await hre.viem.getWalletClients();
		if (!wallets[this.accountIndex]) {
			throw new Error("Could not get a default wallet client from Hardhat.");
		}
		this.walletClient = wallets[this.accountIndex];
		this._address = wallets[this.accountIndex].account.address;

		await super.initialize();
	}

	/**
	 * Synchronously returns the singleton WalletClient instance for the default signer.
	 * Ensure `initializeDefaultWalletClient` has been called and completed before using this.
	 *
	 * @returns The default WalletClient instance.
	 * @throws Error if the client has not been initialized via `initializeDefaultWalletClient`.
	 */
	public getWalletClient(): WalletClient {
		if (!this.walletClient) {
			throw new Error("Wallet client not initialized");
		}

		return this.walletClient;
	}
}

/**
 * A reusable instance of the ClaimIssuer with a consistent address
 */

export const investorA = new Investor("Investor A", 1);
export const investorB = new Investor("Investor B", 2);
