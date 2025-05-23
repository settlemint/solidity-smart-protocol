import hre from "hardhat";
import type { WalletClient } from "viem";

let defaultWalletClientInstance: WalletClient | null = null;

/**
 * Synchronously returns the singleton WalletClient instance for the default signer.
 * Ensure `initializeDefaultWalletClient` has been called and completed before using this.
 *
 * @returns The default WalletClient instance.
 * @throws Error if the client has not been initialized via `initializeDefaultWalletClient`.
 */
export async function getDefaultWalletClient(): Promise<WalletClient> {
	if (defaultWalletClientInstance) {
		return defaultWalletClientInstance;
	}

	const [defaultSigner] = await hre.viem.getWalletClients();
	if (!defaultSigner) {
		throw new Error("Could not get a default wallet client from Hardhat.");
	}
	defaultWalletClientInstance = defaultSigner;
	return defaultWalletClientInstance;
}
