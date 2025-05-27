import { SMARTTopics } from "../constants/topics";
import { smartProtocolDeployer } from "../deployer";
import { getClaimScheme } from "../utils/claim-scheme-utils";

export async function registerTopicScheme() {
	await smartProtocolDeployer
		.getTopicSchemeRegistryContract()
		.write.batchRegisterTopicSchemes([
			[
				SMARTTopics.kyc,
				SMARTTopics.aml,
				SMARTTopics.collateral,
				SMARTTopics.isin,
			],
			[
				getClaimScheme(SMARTTopics.kyc),
				getClaimScheme(SMARTTopics.aml),
				getClaimScheme(SMARTTopics.collateral),
				getClaimScheme(SMARTTopics.isin),
			],
		]);

	console.log("[Register topics] Successfully registered topic schemes.");
}
