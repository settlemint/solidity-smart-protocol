import {
	type Abi,
	type Address,
	type ContractEventName,
	type DecodeEventLogReturnType,
	type Hex,
	type PublicClient,
	type TransactionReceipt,
	type WalletClient,
	decodeEventLog,
} from "viem";
import type { ViemContract } from "../deployer";
import { getPublicClient } from "./public-client";
// Utility function to find specific event arguments from a transaction
export async function waitForEvent<
	const TAbi extends Abi,
	TEventName extends ContractEventName<TAbi>,
>(params: {
	contract: ViemContract<TAbi, { public: PublicClient; wallet: WalletClient }>;
	transactionHash: Hex;
	eventName: TEventName;
}): Promise<DecodeEventLogReturnType<TAbi, TEventName>["args"] | null> {
	const { transactionHash, contract, eventName } = params;
	const contractAddress = contract.address;
	const abi = contract.abi;
	const publicClient = getPublicClient();

	try {
		const receipt: TransactionReceipt =
			await publicClient.waitForTransactionReceipt({ hash: transactionHash });

		console.log("Transaction mined: ", receipt.status);

		if (receipt.status === "success") {
			for (const log of receipt.logs) {
				if (log.address.toLowerCase() === contractAddress.toLowerCase()) {
					try {
						const decodedEvent = decodeEventLog({
							abi: abi,
							data: log.data,
							topics: log.topics,
							eventName: eventName,
						});
						// If decodeEventLog doesn't throw and finds the event, it means topics matched for the specific eventName.
						console.log(`Decoded ${eventName} event args:`, decodedEvent.args);
						return decodedEvent.args as DecodeEventLogReturnType<
							TAbi,
							TEventName
						>["args"];
					} catch (e) {
						// This log is from the correct contract but not the specific event we're looking for,
						// or it was not decodable as such. We can safely ignore this error and continue checking other logs.
						// console.debug(`Log from ${log.address} not matching ${eventName} or decoding error:`, e);
					}
				}
			}
			console.warn(
				`Transaction was successful, but could not find the ${eventName} event from contract ${contractAddress} in the logs.`,
				receipt.logs,
			);
			return null;
		}
		console.error(
			"Transaction failed. Status:",
			receipt.status,
			"Logs:",
			receipt.logs,
		);
		return null;
	} catch (error) {
		console.error(
			"Error waiting for transaction receipt or processing it in findEventArgsFromTransaction:",
			error,
		);
		return null;
	}
}
