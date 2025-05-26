import { type Address, encodeAbiParameters, parseAbiParameters } from "viem";
import { claimIssuer } from "../../actors/claim-issuer";
import { owner } from "../../actors/owner";
import { SMARTContracts } from "../../constants/contracts";
import SMARTTopics from "../../constants/topics";

export const issueIsinClaim = async (
	tokenIdentityAddress: Address,
	isin: string,
) => {
	const encodedIsinData = encodeAbiParameters(
		parseAbiParameters("string isinValue"),
		[isin],
	);

	const { data: isinClaimData, signature: isinClaimSignature } =
		await claimIssuer.createClaim(
			tokenIdentityAddress,
			SMARTTopics.isin,
			encodedIsinData,
		);

	const tokenIdentityContract = owner.getContractInstance({
		address: tokenIdentityAddress,
		abi: SMARTContracts.tokenIdentity,
	});

	const claimIssuerIdentity = await claimIssuer.getIdentity();

	await tokenIdentityContract.write.addClaim([
		SMARTTopics.isin,
		1, // ECDSA
		claimIssuerIdentity,
		isinClaimSignature,
		isinClaimData,
		"",
	]);
};
