import { concat, encodePacked, keccak256, toBytes, toHex } from "viem";
import type { LocalAccount } from "viem/accounts"; // viem signer type

export async function createClaim(
	signer: LocalAccount,
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

	// Use signer from Ignition (m.getAccount(n))
	const signatureHex = await signer.signMessage({
		message: { raw: toBytes(prefixedHash) },
	});

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
