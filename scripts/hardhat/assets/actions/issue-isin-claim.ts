import type { Address } from "viem";
import { claimIssuer } from "../../actors/claim-issuer";
import { owner } from "../../actors/owner";
import { SMARTContracts } from "../../constants/contracts";
import { SMARTTopics } from "../../constants/topics";
import { encodeClaimData } from "../../utils/claim-scheme-utils";
import { waitForSuccess } from "../../utils/wait-for-success";

export const issueIsinClaim = async (
	tokenIdentityAddress: Address,
	isin: string,
) => {
	const encodedIsinData = encodeClaimData(SMARTTopics.isin, [isin]);

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

	const transactionHash = await tokenIdentityContract.write.addClaim([
		SMARTTopics.isin,
		1, // ECDSA
		claimIssuerIdentity,
		isinClaimSignature,
		isinClaimData,
		"",
	]);

	await waitForSuccess(transactionHash);

	console.log(
		`[ISIN claim] issued for token identity ${tokenIdentityAddress} with ISIN ${isin}.`,
	);
};
