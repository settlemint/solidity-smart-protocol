import { smartProtocolDeployer } from "./deployer";
// import hre from "hardhat"; // No longer needed for this specific task

async function main() {
	await smartProtocolDeployer.setUp(); // This now also sets up the default wallet client (Account 0)

	// Get the contract instance. It will use Account 0 by default for writes.
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
}

// Execute the script
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
