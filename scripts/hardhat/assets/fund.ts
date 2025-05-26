import type { Address, Hex } from "viem";
import { claimIssuer } from "../actors/claim-issuer";
import { owner } from "../actors/owner";
import { smartProtocolDeployer } from "../deployer";
import { waitForEvent } from "../utils/wait-for-event";
import { grantClaimManagerRole } from "./actions/grant-claim-manager-role";
import { issueIsinClaim } from "./actions/issue-isin-claim";

export const createFund = async () => {
	const fundFactory = smartProtocolDeployer.getFundFactoryContract();

	// TODO: typing doesn't work? Check txsigner utils
	const transactionHash: Hex = await fundFactory.write.createFund([
		"Bens Bugs",
		"BB",
		8,
		20,
		"Class A",
		"Category A",
		[], // TODO: fill in with the setup for ATK
		[], // TODO: fill in with the setup for ATK
	]);

	const { tokenAddress, tokenIdentity, accessManager } = (await waitForEvent({
		transactionHash,
		contract: fundFactory,
		eventName: "TokenAssetCreated",
	})) as unknown as {
		sender: Address;
		tokenAddress: Address;
		tokenIdentity: Address;
		accessManager: Address;
	};

	if (tokenAddress && tokenIdentity && accessManager) {
		console.log("[Fund] address:", tokenAddress);
		console.log("[Fund] identity:", tokenIdentity);
		console.log("[Fund] access manager:", accessManager);

		// needs to be done so that he can add the claims
		await grantClaimManagerRole(accessManager, owner.address);
		// issue isin claim
		await issueIsinClaim(tokenIdentity, "12345678901234567890");

		// TODO: execute all other functions of the fund

		return tokenAddress;
	}

	throw new Error("Failed to create deposit");
};
