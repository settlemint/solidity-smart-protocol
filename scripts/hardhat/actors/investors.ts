import hre from "hardhat";
import { Chain, Transport, WalletClient } from "viem";
import { Account } from "viem/accounts";
import { Countries } from "../constants/countries";
import { AbstractActor } from "./abstract-actor";

/**
 * Class representing an investor that can generate and sign claims
 */
class Investor extends AbstractActor {
	private accountIndex: number;
	private walletClient: WalletClient<Transport, Chain, Account> | null = null;
	/**
	 * Create a new investor
	 * @param name - The name of the investor
	 * @param countryCode - The country code of the investor
	 * @param accountIndex - The index of the account in the wallet clients array
	 */
	constructor(name: string, countryCode: number, accountIndex: number) {
		super(name, countryCode);
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
	public getWalletClient(): WalletClient<Transport, Chain, Account> {
		if (!this.walletClient) {
			throw new Error("Wallet client not initialized");
		}

		return this.walletClient;
	}
}

/**
 * A reusable instance of the ClaimIssuer with a consistent address
 */

export const investorA = new Investor("Investor A", Countries.BE, 1);
export const investorB = new Investor("Investor B", Countries.NL, 2);
