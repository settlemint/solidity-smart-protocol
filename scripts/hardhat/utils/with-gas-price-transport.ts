import { type Transport, custom, toHex } from "viem";

interface ProviderWithRequest {
	request: (args: {
		method: string;
		params?: unknown[] | object;
	}) => Promise<unknown>;
}

export function withZeroGasTransport(
	baseProvider: ProviderWithRequest,
): Transport {
	return custom({
		...baseProvider,
		request: async (args) => {
			console.log(
				`Executing ${args.method} with params ${JSON.stringify(args.params)}`,
			);

			// Handle transaction sending with zero gas
			if (args.method === "eth_sendTransaction" && args.params?.[0]) {
				const tx = args.params[0];

				// Force zero gas pricing - both legacy and EIP-1559
				tx.gasPrice = "0x0";
				tx.maxFeePerGas = "0x0";
				tx.maxPriorityFeePerGas = "0x0";

				// Set high gas limit if not specified
				if (!tx.gas) {
					tx.gas = toHex(30000000n);
				}

				console.log("Zero gas transaction:", tx);
			}

			// Intercept and modify raw transactions if they have non-zero gas fees
			if (args.method === "eth_sendRawTransaction" && args.params?.[0]) {
				console.log("Intercepting raw transaction to check gas fees");
				// For zero gas networks, we should not be sending transactions with fees
				// If we reach here, viem has encoded a transaction with fees despite our settings
				// This suggests the account balance issue - let's add more ETH to the account
			}

			// Handle gas estimation - return high gas limit
			if (args.method === "eth_estimateGas") {
				console.log("Gas estimation requested, returning high limit");
				return toHex(30000000n);
			}

			// Handle gas price requests - return zero
			if (args.method === "eth_gasPrice") {
				console.log("Gas price requested, returning zero");
				return "0x0";
			}

			// Handle fee history requests for EIP-1559
			if (args.method === "eth_feeHistory") {
				console.log("Fee history requested, returning zero fees");
				return {
					baseFeePerGas: ["0x0"],
					gasUsedRatio: [0],
					reward: [["0x0"]],
				};
			}

			return baseProvider.request(args);
		},
	});
}
