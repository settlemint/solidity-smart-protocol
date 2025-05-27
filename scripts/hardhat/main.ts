import { batchAddToRegistry } from "./actions/add-to-registry";
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
import { SMARTTopics } from "./constants/topics";
import { smartProtocolDeployer } from "./deployer";

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

	// Add the actors to the registry
	await batchAddToRegistry([owner, investorA, investorB]);

	// make sure every actor is verified
	await Promise.all([
		issueVerificationClaims(owner),
		issueVerificationClaims(investorA),
		issueVerificationClaims(investorB),
	]);

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
