// import hre from "hardhat"; // No longer needed for this specific task
import {
	type Address,
	type Hex,
	encodeAbiParameters,
	parseAbiParameters,
	toBytes,
} from "viem";
import { SMARTContracts } from "./constants/contracts";
import SMARTTopics from "./constants/topics";
import { smartProtocolDeployer } from "./deployer";
import { claimIssuer } from "./utils/claim-issuer";
import { getPublicClient } from "./utils/public-client";
import { waitForEvent } from "./utils/wait-for-event";
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
	const transactionHash: Hex = await depositFactory.write.createDeposit([
		"Euro Deposits",
		"EURD",
		6,
		[], // TODO: fill in with the setup for ATK
		[], // TODO: fill in with the setup for ATK
	]);

	const { tokenAddress, tokenIdentity, accessManager } = (await waitForEvent({
		transactionHash,
		contract: depositFactory,
		eventName: "TokenAssetCreated",
	})) as unknown as {
		sender: Address;
		tokenAddress: Address;
		tokenIdentity: Address;
		accessManager: Address;
	};

	if (tokenAddress && tokenIdentity && accessManager) {
		console.log("Token address:", tokenAddress);
		console.log("Token identity:", tokenIdentity);
		console.log("Access manager:", accessManager);

		const isinValue = "12345678901234567890";
		const encodedIsinData = toBytes(
			encodeAbiParameters(parseAbiParameters("string isinValue"), [isinValue]),
		);

		const isinClaim = await claimIssuer.createClaim(
			tokenIdentity,
			SMARTTopics.isin,
			encodedIsinData,
		);

		console.log("Isin claim:", isinClaim);

		const accessManagerContract = getViemContract({
			address: tokenAddress,
			abi: SMARTContracts.accessManager,
			client: { public: getPublicClient(), wallet: walletToUse },
		});
	}
}

// Execute the script
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
