import type { Abi, Address } from "viem";
import { owner } from "../../actors/owner";
import { SMARTContracts } from "../../constants/contracts";
import { formatDecimals } from "../../utils/format-decimals";
import { toDecimals } from "../../utils/to-decimals";
import { waitForSuccess } from "../../utils/wait-for-success";

export const mint = async (
	tokenAddress: Address,
	amount: bigint,
	decimals: number,
	userAddress: Address,
) => {
	const tokenContract = owner.getContractInstance({
		address: tokenAddress,
		abi: SMARTContracts.deposit,
	});

	const tokenAmount = toDecimals(amount, decimals);

	const transactionHash = await tokenContract.write.mint([
		userAddress,
		tokenAmount,
	]);

	await waitForSuccess(transactionHash);

	console.log(
		`[Mint] ${formatDecimals(tokenAmount, decimals)} tokens to ${userAddress}`,
	);
};
