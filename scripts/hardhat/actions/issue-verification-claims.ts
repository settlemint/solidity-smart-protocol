import { type Address, encodeAbiParameters, parseAbiParameters } from "viem";
import type { AbstractActor } from "../actors/abstract-actor";
import { claimIssuer } from "../actors/claim-issuer";
import { owner } from "../actors/owner";
import { SMARTContracts } from "../constants/contracts";
import SMARTTopics from "../constants/topics";
import { waitForSuccess } from "../utils/wait-for-success";

export const issueVerificationClaims = async (actor: AbstractActor) => {
	const claimIssuerIdentity = await claimIssuer.getIdentity();

	// await Promise.all([
	await _issueClaim(
		actor,
		claimIssuerIdentity,
		SMARTTopics.kyc,
		`KYC verified by ${claimIssuerIdentity}`,
	);
	await _issueClaim(
		actor,
		claimIssuerIdentity,
		SMARTTopics.aml,
		`AML verified by ${claimIssuerIdentity}`,
	);
	// ]);
};

async function _issueClaim(
	actor: AbstractActor,
	claimIssuerIdentity: Address,
	claimTopic: bigint,
	claimData: string,
) {
	const encodedClaimData = encodeAbiParameters(parseAbiParameters("string"), [
		claimData,
	]);

	const identityAddress = await actor.getIdentity();

	const { signature: claimSignature } = await claimIssuer.createClaim(
		identityAddress,
		claimTopic,
		encodedClaimData,
	);

	const identityContract = actor.getContractInstance({
		address: identityAddress,
		abi: SMARTContracts.identity,
	});

	const transactionHash = await identityContract.write.addClaim([
		claimTopic,
		1, // ECDSA
		claimIssuerIdentity,
		claimSignature,
		encodedClaimData,
		"",
	]);

	await waitForSuccess(transactionHash);

	console.log(
		`[Verification claims] "${claimData}"" issued for identity ${identityAddress}.`,
	);
}
