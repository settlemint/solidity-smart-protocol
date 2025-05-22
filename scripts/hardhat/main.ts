import { smartProtocolDeployer } from "./deployer";

async function main() {
	await smartProtocolDeployer.setUp();

	smartProtocolDeployer.depositFactoryContract.write.createDeposit(
		"Euro Deposits",
		"EURD",
		6,
		[], // TODO: fill in with the setup for ATK
		[], // TODO: fill in with the setup for ATK
	);
}

// Execute the script
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
