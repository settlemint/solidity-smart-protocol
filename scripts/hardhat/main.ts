import type { Hex } from "viem";
import { createBond } from "./assets/bond";
import { createDeposit } from "./assets/deposit";
import { createEquity } from "./assets/equity";
import { createFund } from "./assets/fund";
import { createStablecoin } from "./assets/stablecoin";
import SMARTTopics from "./constants/topics";
import { smartProtocolDeployer } from "./deployer";
import { claimIssuer } from "./utils/claim-issuer";
import { waitForSuccess } from "./utils/wait-for-success";
async function main() {
	// Setup the smart protocol
	await smartProtocolDeployer.setUp();

	// Set up the claim issuer as a trusted issuer
	const trustedIssuersRegistry =
		smartProtocolDeployer.getTrustedIssuersRegistryContract();
	const claimIssuerIdentity = await claimIssuer.getOrCreateIdentity();
	const transactionHash: Hex =
		await trustedIssuersRegistry.write.addTrustedIssuer([
			claimIssuerIdentity,
			[SMARTTopics.kyc, SMARTTopics.aml, SMARTTopics.collateral],
		]);

	await waitForSuccess(transactionHash);

	// Create the assets
	const deposit = await createDeposit();
	const equity = await createEquity();
	const bond = await createBond(deposit);
	const fund = await createFund();
	const stablecoin = await createStablecoin();
}

// Execute the script
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
