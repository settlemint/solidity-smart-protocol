import type { Address, Hex } from "viem";
import { claimIssuer } from "../actors/claim-issuer";
import { smartProtocolDeployer } from "../deployer";
import { waitForEvent } from "../utils/wait-for-event";
import { grantClaimManagerRole } from "./actions/grant-claim-manager-role";
import { issueIsinClaim } from "./actions/issue-isin-claim";

export const createEquity = async () => {
	const equityFactory = smartProtocolDeployer.getEquityFactoryContract();

	// TODO: typing doesn't work? Check txsigner utils
	const transactionHash: Hex = await equityFactory.write.createEquity([
		"Apple",
		"AAPL",
		18,
		"Class A",
		"Category A",
		[], // TODO: fill in with the setup for ATK
		[], // TODO: fill in with the setup for ATK
	]);

	const { tokenAddress, tokenIdentity, accessManager } = (await waitForEvent({
		transactionHash,
		contract: equityFactory,
		eventName: "TokenAssetCreated",
	})) as unknown as {
		sender: Address;
		tokenAddress: Address;
		tokenIdentity: Address;
		accessManager: Address;
	};

	if (tokenAddress && tokenIdentity && accessManager) {
		console.log("Equity address:", tokenAddress);
		console.log("Equity identity:", tokenIdentity);
		console.log("Equity access manager:", accessManager);

		// needs to be done so that he can add the claims
		await grantClaimManagerRole(accessManager, claimIssuer.address);
		// issue isin claim
		await issueIsinClaim(tokenIdentity, "12345678901234567890");

		// TODO: execute all other functions of the equity

		return tokenAddress;
	}

	throw new Error("Failed to create equity");
};
