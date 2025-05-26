import type { Address, Hex } from "viem";
import { claimIssuer } from "../actors/claim-issuer";
import { owner } from "../actors/owner";
import { smartProtocolDeployer } from "../deployer";
import { waitForEvent } from "../utils/wait-for-event";
import { grantClaimManagerRole } from "./actions/grant-claim-manager-role";
import { issueIsinClaim } from "./actions/issue-isin-claim";

export const createBond = async (depositToken: Address) => {
	const bondFactory = smartProtocolDeployer.getBondFactoryContract();

	// TODO: typing doesn't work? Check txsigner utils
	const transactionHash: Hex = await bondFactory.write.createBond([
		"Euro Bonds",
		"EURB",
		6,
		1000000 * 10 ** 6,
		Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60, // 1 year
		123,
		depositToken,
		[], // TODO: fill in with the setup for ATK
		[], // TODO: fill in with the setup for ATK
	]);

	const { tokenAddress, tokenIdentity, accessManager } = (await waitForEvent({
		transactionHash,
		contract: bondFactory,
		eventName: "TokenAssetCreated",
	})) as unknown as {
		sender: Address;
		tokenAddress: Address;
		tokenIdentity: Address;
		accessManager: Address;
	};

	if (tokenAddress && tokenIdentity && accessManager) {
		console.log("Bond address:", tokenAddress);
		console.log("Bond identity:", tokenIdentity);
		console.log("Bond access manager:", accessManager);

		// needs to be done so that he can add the claims
		await grantClaimManagerRole(accessManager, owner.address);
		// issue isin claim
		await issueIsinClaim(tokenIdentity, "12345678901234567890");

		// TODO: add yield etc
		// TODO: execute all other functions of the bond

		return tokenAddress;
	}

	throw new Error("Failed to create bond");
};
