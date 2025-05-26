import type { Abi, Address } from "viem";
import { owner } from "../../actors/owner";
import { SMARTContracts } from "../../constants/contracts";
import { waitForSuccess } from "../../utils/wait-for-success";

export const mint = async (
	tokenAddress: Address,
	amount: bigint,
	userAddress: Address,
) => {
	const tokenContract = owner.getContractInstance({
		address: tokenAddress,
		abi: SMARTContracts.deposit,
	});

	const transactionHash = await tokenContract.write.mint([userAddress, amount]);

	await waitForSuccess(transactionHash);

	console.log(`[Mint] ${amount} tokens to ${userAddress}`);
};
