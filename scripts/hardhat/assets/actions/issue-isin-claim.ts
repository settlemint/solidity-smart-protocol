import type { Address } from "viem";
import { claimIssuer } from "../../actors/claim-issuer";
import { owner } from "../../actors/owner";
import { SMARTContracts } from "../../constants/contracts";
import { SMARTTopic } from "../../constants/topics";
import { topicManager } from "../../services/topic-manager";
import { encodeClaimData } from "../../utils/claim-scheme-utils";
import { waitForSuccess } from "../../utils/wait-for-success";

export const issueIsinClaim = async (
	tokenIdentityAddress: Address,
	isin: string
) => {
	const encodedIsinData = encodeClaimData(SMARTTopic.isin, [isin]);

	const {
		data: isinClaimData,
		signature: isinClaimSignature,
		topicId,
	} = await claimIssuer.createClaim(
		tokenIdentityAddress,
		SMARTTopic.isin,
		encodedIsinData
	);

	const tokenIdentityContract = owner.getContractInstance({
		address: tokenIdentityAddress,
		abi: SMARTContracts.tokenIdentity,
	});

	const claimIssuerIdentity = await claimIssuer.getIdentity();

	const transactionHash = await tokenIdentityContract.write.addClaim(
		[
			topicId,
			topicManager.getTopicId(SMARTTopic.isin), // ECDSA
			claimIssuerIdentity,
			isinClaimSignature,
			isinClaimData,
			"",
		],
		{
			account: null,
			chain: undefined,
		}
	);

	await waitForSuccess(transactionHash);

	console.log(
		`[ISIN claim] issued for token identity ${tokenIdentityAddress} with ISIN ${isin}.`
	);
};
