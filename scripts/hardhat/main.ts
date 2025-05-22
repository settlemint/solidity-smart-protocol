import SMARTTopics from "./constants/topics";
import { smartProtocolDeployer } from "./deployer";
import { claimIssuer } from "./utils/claim-issuer";
// import hre from "hardhat"; // No longer needed for this specific task

async function main() {
	await smartProtocolDeployer.setUp();

	// Set up the claim issuer as a trusted issuer
	const trustedIssuersRegistry =
		smartProtocolDeployer.getTrustedIssuersRegistryContract();
	await trustedIssuersRegistry.write.addTrustedIssuer([
		claimIssuer.address,
		[SMARTTopics.kyc, SMARTTopics.aml, SMARTTopics.collateral],
	]);

	const depositFactory = smartProtocolDeployer.getDepositFactoryContract();

	// TODO: typing doesn't work? Check txsigner utils
	const transactionHash = await depositFactory.write.createDeposit([
		"Euro Deposits",
		"EURD",
		6,
		[], // TODO: fill in with the setup for ATK
		[], // TODO: fill in with the setup for ATK
	]);

	console.log("Deposit created. Transaction Hash:", transactionHash);

	// claimIssuer.createClaim(
	// 	,
	// 	SMARTTopics.kyc,
	// 	new Uint8Array(),
	// );
}

// Execute the script
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
