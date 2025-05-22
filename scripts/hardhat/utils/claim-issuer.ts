import type { Signer } from "ethers"; // ethers signer type
import { concat, encodePacked, keccak256, toBytes, toHex } from "viem";
import type { LocalAccount } from "viem/accounts"; // viem signer type
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";

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
		claimData: Uint8Array,
	): Promise<{ data: Uint8Array; signature: Uint8Array }> {
		return createClaim(
			this.signer,
			subjectIdentityAddress,
			claimTopic,
			claimData,
		);
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
	claimData: Uint8Array,
): Promise<{ data: Uint8Array; signature: Uint8Array }> {
	// Solidity-style hash: keccak256(abi.encode(address, uint256, bytes))
	const dataHash = keccak256(
		toBytes(
			encodePacked(
				["address", "uint256", "bytes"],
				[subjectIdentityAddress, claimTopic, toHex(claimData)],
			),
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

	// Extract r, s, v
	const r = signatureHex.slice(2, 66);
	const s = signatureHex.slice(66, 130);
	const v = signatureHex.slice(130, 132);

	const signature = toBytes(`0x${r}${s}${v}`);

	return {
		data: claimData,
		signature,
	};
}

/**
 * A reusable instance of the ClaimIssuer with a consistent address
 */
export const claimIssuer = new ClaimIssuer();
