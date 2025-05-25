import hre from "hardhat";
import * as viemChains from "viem/chains";

let viemChainInstance: viemChains.Chain | null = null;

// Helper function to get Viem chain object from chainId
export function getViemChain(): viemChains.Chain {
  if (viemChainInstance) {
    return viemChainInstance;
  }

  if (hre.network.name === "localhost") {
    viemChainInstance = viemChains.hardhat;
    return viemChainInstance;
  }

  const chainId = hre.network.config?.chainId;
  if (typeof chainId !== "number") {
    throw new Error(
      "Chain ID not found in Hardhat network configuration. Cannot initialize PublicClient."
    );
  }

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
    `Viem chain definition not found for chainId ${chainId}. Defaulting to Hardhat local chain (chain ID: ${viemChains.hardhat.id}). This may not be suitable for all environments.`
  );
  viemChainInstance = viemChains.hardhat;

  return viemChainInstance;
}
