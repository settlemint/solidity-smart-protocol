import {
	type Address,
	encodeAbiParameters,
	parseAbiParameters,
	toBytes,
} from "viem";
import { SMARTContracts } from "../../constants/contracts";
import SMARTTopics from "../../constants/topics";
import { claimIssuer } from "../../utils/claim-issuer";
import { getContractInstanceWithDefaultWalletClient } from "../../utils/get-contract";

export const issueIsinClaim = async (
	tokenIdentityAddress: Address,
	isin: string,
) => {
	const encodedIsinData = toBytes(
		encodeAbiParameters(parseAbiParameters("string isinValue"), [isin]),
	);

	const { data: isinClaimData, signature: isinClaimSignature } =
		await claimIssuer.createClaim(
			tokenIdentityAddress,
			SMARTTopics.isin,
			encodedIsinData,
		);

	console.log("Isin claim:", isinClaimData, isinClaimSignature);

	const tokenIdentityContract =
		await getContractInstanceWithDefaultWalletClient({
			address: tokenIdentityAddress,
			abi: SMARTContracts.tokenIdentity,
		});

	await tokenIdentityContract.write.addClaim([
		SMARTTopics.isin,
		1, // ECDSA
		claimIssuer.address,
		isinClaimSignature,
		isinClaimData,
		"",
	]);
};
