import hre from "hardhat";
import type { WalletClient } from "viem";
import { AbstractActor } from "./abstract-actor";

const defaultWalletClientInstance: WalletClient | null = null;

class Owner extends AbstractActor {
	private walletClient: WalletClient | null = null;

	public async initialize(): Promise<void> {
		await super.initialize();

		const [defaultSigner] = await hre.viem.getWalletClients();
		if (!defaultSigner) {
			throw new Error("Could not get a default wallet client from Hardhat.");
		}
		this.walletClient = defaultSigner;
		this._address = defaultSigner.account.address;
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

export const owner = new Owner();
