import type { Address, Hex } from "viem";
import { SMARTContracts } from "../../constants/contracts";
import SMARTRoles from "../../constants/roles";
import { getContractInstanceWithDefaultWalletClient } from "../../utils/get-contract";
import { waitForSuccess } from "../../utils/wait-for-success";

// The issuer doesn't need to have a claim manager role, it can be anyone that adds the claim.
// The issuer will create the claim and the claim manager will add it to the token identity.
export const grantClaimManagerRole = async (
	accessManagerAddress: Address,
	claimIssuerAddress: Address,
) => {
	const accessManagerContract =
		await getContractInstanceWithDefaultWalletClient({
			address: accessManagerAddress,
			abi: SMARTContracts.accessManager,
		});

	const transactionHash: Hex = await accessManagerContract.write.grantRole([
		SMARTRoles.claimManagerRole,
		claimIssuerAddress,
	]);

	await waitForSuccess(transactionHash);
};
