import { type Address, formatEther, formatUnits } from "viem";
import { addTrustedIssuer } from "./actions/add-trusted-issuer";
import { issueVerificationClaims } from "./actions/issue-verification-claims";
import { claimIssuer } from "./actors/claim-issuer";
import { investorA, investorB } from "./actors/investors";
import { owner } from "./actors/owner";
import { createBond } from "./assets/bond";
import { createDeposit } from "./assets/deposit";
import { createEquity } from "./assets/equity";
import { createFund } from "./assets/fund";
import { createStablecoin } from "./assets/stablecoin";
import { SMARTContracts } from "./constants/contracts";
import SMARTTopics from "./constants/topics";
import { smartProtocolDeployer } from "./deployer";
import { getPublicClient } from "./utils/public-client";

async function main() {
	// Setup the smart protocol
	await smartProtocolDeployer.setUp({
		displayUi: true,
	});

	// Initialize the actors
	await Promise.all([
		owner.initialize(),
		claimIssuer.initialize(),
		investorA.initialize(),
		investorB.initialize(),
	]);

	// Print initial balances
	await owner.printBalance();
	await claimIssuer.printBalance();
	await investorA.printBalance();
	await investorB.printBalance();

	// Add the claim issuer as a trusted issuer
	const claimIssuerIdentity = await claimIssuer.getIdentity();
	await addTrustedIssuer(claimIssuerIdentity, [
		SMARTTopics.kyc,
		SMARTTopics.aml,
		SMARTTopics.collateral,
	]);

	// Make sure the investor has a kyc claim
	await issueVerificationClaims(investorA);
	await issueVerificationClaims(investorB);

	// Create the assets and print balances after each creation
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
