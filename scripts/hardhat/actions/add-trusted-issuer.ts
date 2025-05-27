import type { Address, Hex } from "viem";
import SMARTTopics from "../constants/topics";
import { smartProtocolDeployer } from "../deployer";
import { waitForSuccess } from "../utils/wait-for-success";
export const addTrustedIssuer = async (
	trustedIssuerIdentity: Address,
	claimTopics: bigint[] = [
		SMARTTopics.kyc,
		SMARTTopics.aml,
		SMARTTopics.collateral,
	],
) => {
	// Set up the claim issuer as a trusted issuer
	const trustedIssuersRegistry =
		smartProtocolDeployer.getTrustedIssuersRegistryContract();

	const transactionHash: Hex =
		await trustedIssuersRegistry.write.addTrustedIssuer([
			trustedIssuerIdentity,
			claimTopics,
		]);

	await waitForSuccess(transactionHash);

	console.log(
		`[Add trusted issuer] ${trustedIssuerIdentity} added to registry`,
	);
};
