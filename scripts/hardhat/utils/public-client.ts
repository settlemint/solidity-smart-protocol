import hre from "hardhat";
import { type PublicClient, createPublicClient, custom } from "viem";
import * as viemChains from "viem/chains";

// Helper function to get Viem chain object from chainId
function getViemChain(chainId: number): viemChains.Chain {
	for (const chainKey in viemChains) {
		// biome-ignore lint/suspicious/noExplicitAny: Iterating over module exports
		const chain = (viemChains as any)[chainKey] as viemChains.Chain;
		if (chain.id === chainId) {
			return chain;
		}
	}
	// Fallback to Hardhat local chain if no specific chain is found
	// This is useful for local development and testing
	console.warn(
		`Viem chain definition not found for chainId ${chainId}. Defaulting to Hardhat local chain (chain ID: ${viemChains.hardhat.id}). This may not be suitable for all environments.`,
	);
	return viemChains.hardhat;
}

let publicClientInstance: PublicClient | null = null;

/**
 * Returns a singleton PublicClient instance.
 * If the client has not been initialized, it will be initialized using the provided Hardhat Runtime Environment.
 * Subsequent calls will return the existing instance.
 *
 * @param hardhatRuntimeEnv - The Hardhat Runtime Environment, used to access network configuration for initialization.
 * @returns The PublicClient instance.
 * @throws Error if chainId is not found in Hardhat network configuration during initialization.
 */
export function getPublicClient(): PublicClient {
	if (publicClientInstance) {
		return publicClientInstance;
	}

	const chainId = hre.network.config?.chainId;
	if (typeof chainId !== "number") {
		throw new Error(
			"Chain ID not found in Hardhat network configuration. Cannot initialize PublicClient.",
		);
	}
	const viemChain = getViemChain(chainId);

	publicClientInstance = createPublicClient({
		chain: viemChain,
		transport: custom(hre.network.provider), // Use Hardhat's EIP-1193 provider
	});

	return publicClientInstance;
}
