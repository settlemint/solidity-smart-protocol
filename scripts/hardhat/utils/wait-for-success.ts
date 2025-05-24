import type { Hex, TransactionReceipt } from "viem";
import { getPublicClient } from "./public-client";

export async function waitForSuccess(transactionHash: Hex) {
	const publicClient = getPublicClient();
	const receipt: TransactionReceipt =
		await publicClient.waitForTransactionReceipt({ hash: transactionHash });

	if (receipt.status === "success") {
		return receipt;
	}

	throw new Error(`Transaction with hash ${transactionHash} failed`);
}
