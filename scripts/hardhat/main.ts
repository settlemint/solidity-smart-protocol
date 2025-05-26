import type { Hex } from "viem";
import {
	encodeAbiParameters,
	keccak256,
	padHex,
	parseAbiParameters,
} from "viem";
import { createBond } from "./assets/bond";
import { createDeposit } from "./assets/deposit";
import { createEquity } from "./assets/equity";
import { createFund } from "./assets/fund";
import { createStablecoin } from "./assets/stablecoin";
import { SMARTContracts } from "./constants/contracts";
import SMARTTopics from "./constants/topics";
import { smartProtocolDeployer } from "./deployer";
import { claimIssuer } from "./utils/claim-issuer";
import { getContractInstance } from "./utils/get-contract";
import { waitForSuccess } from "./utils/wait-for-success";
async function main() {
	// Setup the smart protocol
	await smartProtocolDeployer.setUp({
		displayUi: true,
	});

	// Set up the claim issuer as a trusted issuer
	const trustedIssuersRegistry =
		smartProtocolDeployer.getTrustedIssuersRegistryContract();
	const claimIssuerIdentity = await claimIssuer.getOrCreateIdentity();

	const claimIssuerIdentityContract = await getContractInstance({
		address: claimIssuerIdentity,
		abi: SMARTContracts.identity,
		walletClient: claimIssuer.getWalletClient(),
	});

	const keyForHash = claimIssuer.address;
	const encodedKey = encodeAbiParameters(parseAbiParameters("address"), [
		keyForHash,
	]);
	const keyHash = keccak256(encodedKey);

	const isSignerKey = await claimIssuerIdentityContract.read.keyHasPurpose([
		keyHash,
		BigInt(3),
	]);
	console.log("Is signer key:", isSignerKey);

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
