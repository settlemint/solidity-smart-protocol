// import hre from "hardhat"; // No longer needed for this specific task
import type { Hex, TransactionReceipt } from "viem"; // Added import for viem types
import { type Abi, type Address, decodeEventLog } from "viem"; // Added decodeEventLog and Abi/Address
import SMARTTopics from "./constants/topics";
import { smartProtocolDeployer } from "./deployer";
import { claimIssuer } from "./utils/claim-issuer";

async function main() {
	await smartProtocolDeployer.setUp();

	// Assuming smartProtocolDeployer has a publicClient instance or a method to get one.
	// PLEASE ADJUST THE LINE BELOW (and its potential import) BASED ON YOUR ACTUAL smartProtocolDeployer STRUCTURE.
	// Examples:
	// const publicClient = smartProtocolDeployer.publicClient;
	// const publicClient = smartProtocolDeployer.getPublicClient();
	// If not available, you might need to create one:
	// import { createPublicClient, http } from 'viem';
	// import { hardhat } from 'viem/chains'; // Or your specific chain
	// const publicClient = createPublicClient({ chain: hardhat, transport: http() });
	// For this example, we'll assume smartProtocolDeployer.publicClient exists.
	const publicClient = smartProtocolDeployer.getPublicClient();

	if (!publicClient) {
		console.error(
			"Failed to get publicClient from smartProtocolDeployer. Please ensure it's exposed (e.g., as smartProtocolDeployer.publicClient) or create one manually.",
		);
		process.exit(1);
		return; // For type safety, though process.exit will terminate
	}

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

	console.log("CreateDeposit transaction sent. Hash:", transactionHash);
	console.log("Waiting for transaction to be mined...");

	try {
		// Wait for the transaction to be mined and get the receipt
		const receipt: TransactionReceipt =
			await publicClient.waitForTransactionReceipt({ hash: transactionHash });

		console.log("Transaction mined. Full receipt:", receipt);

		if (receipt.status === "success") {
			// The contractAddress on the main receipt will be null because this tx calls a factory,
			// which *internally* deploys the contract. We need to find the address from emitted events.
			let deployedDepositContractAddress: Address | null = null;

			const depositFactoryContract =
				smartProtocolDeployer.getDepositFactoryContract();
			const depositFactoryAbi = depositFactoryContract.abi as Abi;

			for (const log of receipt.logs) {
				if (
					log.address.toLowerCase() ===
					depositFactoryContract.address.toLowerCase()
				) {
					try {
						const decodedEvent = decodeEventLog({
							abi: depositFactoryAbi,
							data: log.data as Hex,
							topics: log.topics as [Hex, ...Hex[]],
						});

						// Specifically look for the TokenAssetCreated event and its tokenAddress argument
						if (decodedEvent.eventName === "TokenAssetCreated") {
							console.log(
								"Decoded TokenAssetCreated event args:",
								decodedEvent.args,
							);
							const eventArgs = decodedEvent.args as unknown as {
								sender: Address;
								tokenAddress: Address;
								tokenIdentity: Address;
								accessManager: Address;
							};

							if (eventArgs?.tokenAddress) {
								console.log(
									`Found TokenAssetCreated event. Deployed deposit contract address: ${eventArgs.tokenAddress}`,
								);
								deployedDepositContractAddress = eventArgs.tokenAddress;
								break; // Found the address, exit the loop
							}
						}
					} catch (e) {
						// This log might not be decodable with the known ABI or not the event of interest
						// console.debug("Skipping log, could not decode or not target event:", e);
					}
				}
				if (deployedDepositContractAddress) break; // Found address, exit outer loop
			}

			if (deployedDepositContractAddress) {
				console.log(
					"Deposit contract successfully created at address:",
					deployedDepositContractAddress,
				);
				// You can now use the deployedDepositContractAddress for further interactions
			} else {
				console.warn(
					"Transaction was successful, but could not determine the deployed contract address from the factory's events.",
				);
			}
		} else {
			console.error("Transaction failed. Status:", receipt.status);
			// You might want to log more details from the receipt for debugging, e.g., receipt.logs
		}
	} catch (error) {
		console.error(
			"Error waiting for transaction receipt or processing it:",
			error,
		);
	}

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
