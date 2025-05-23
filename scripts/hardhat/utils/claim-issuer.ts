import type { Signer } from "ethers"; // ethers signer type
import hre from "hardhat";
import {
	http,
	Transport,
	type WalletClient,
	concat,
	createWalletClient,
	custom,
	encodePacked,
	keccak256,
	toBytes,
	toHex,
} from "viem";
import type { LocalAccount } from "viem/accounts"; // viem signer type
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import type { Chain } from "viem/chains";
import { getViemChain } from "./viem-chain";

/**
 * Class representing a claim issuer that can generate and sign claims
 */
class ClaimIssuer {
	private readonly signer: LocalAccount;

	/**
	 * Create a new claim issuer
	 * @param privateKey - Optional private key for the signer. If not provided, a random one will be generated.
	 */
	constructor(privateKey?: `0x${string}`) {
		const pk = privateKey ?? generatePrivateKey();
		this.signer = privateKeyToAccount(pk);
	}

	/**
	 * Get the address of the claim issuer
	 */
	get address(): `0x${string}` {
		return this.signer.address;
	}

	/**
	 * Create a claim signed by this issuer
	 * @param subjectIdentityAddress - The address of the identity to attach the claim to
	 * @param claimTopic - The topic of the claim
	 * @param claimData - The data of the claim
	 * @returns The claim data and signature
	 */
	async createClaim(
		subjectIdentityAddress: `0x${string}`,
		claimTopic: bigint,
		claimData: `0x${string}`,
	): Promise<{ data: `0x${string}`; signature: `0x${string}` }> {
		return createClaim(
			this.signer,
			subjectIdentityAddress,
			claimTopic,
			claimData,
		);
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
 * Creates a claim signed by the provided signer
 * @param signer - Either a viem LocalAccount or an ethers Signer
 * @param subjectIdentityAddress - The address of the identity to attach the claim to
 * @param claimTopic - The topic of the claim
 * @param claimData - The data of the claim
 * @returns The claim data and signature
 */
export async function createClaim(
	signer: LocalAccount | Signer,
	subjectIdentityAddress: `0x${string}`,
	claimTopic: bigint,
	claimData: `0x${string}`,
): Promise<{ data: `0x${string}`; signature: `0x${string}` }> {
	// Solidity-style hash: keccak256(abi.encode(address, uint256, bytes))
	const dataHash = keccak256(
		encodePacked(
			["address", "uint256", "bytes"],
			[subjectIdentityAddress, claimTopic, claimData],
		),
	);

	// Ethereum Signed Message hash
	const prefixedHash = keccak256(
		concat([toBytes("\x19Ethereum Signed Message:\n32"), toBytes(dataHash)]),
	);

	let signatureHex: `0x${string}`;

	// Check if it's a viem signer or an ethers signer
	if (
		"signMessage" in signer &&
		typeof signer.signMessage === "function" &&
		"address" in signer
	) {
		// viem signer
		signatureHex = await signer.signMessage({
			message: { raw: toBytes(prefixedHash) },
		});
	} else {
		// ethers signer
		const ethersSigner = signer as Signer;
		const signature = await ethersSigner.signMessage(toBytes(prefixedHash));
		signatureHex = signature as `0x${string}`;
	}

	// The signatureHex is already a complete hex string (r + s + v)
	// No need to extract r, s, v separately if the contract expects a flat bytes signature.
	// If the contract expects r, s, v separately, then the extraction is needed.
	// Assuming the contract's addClaim function expects `bytes memory signature` which can be a flat hex string.

	return {
		data: claimData,
		signature: signatureHex,
	};
}

/**
 * A reusable instance of the ClaimIssuer with a consistent address
 */
export const claimIssuer = new ClaimIssuer();
