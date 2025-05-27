import type { Address, Hex } from "viem";

import { investorA } from "../actors/investors";
import { owner } from "../actors/owner";
import { SMARTRoles } from "../constants/roles";
import { SMARTTopics } from "../constants/topics";
import { smartProtocolDeployer } from "../deployer";
import { waitForEvent } from "../utils/wait-for-event";
import { grantRole } from "./actions/grant-role";
import { issueCollateralClaim } from "./actions/issue-collateral-claim";
import { issueIsinClaim } from "./actions/issue-isin-claim";
import { mint } from "./actions/mint";

export const createEquity = async () => {
	const equityFactory = smartProtocolDeployer.getEquityFactoryContract();

	// TODO: typing doesn't work? Check txsigner utils
	const transactionHash: Hex = await equityFactory.write.createEquity([
		"Apple",
		"AAPL",
		18,
		"Class A",
		"Category A",
		[SMARTTopics.kyc, SMARTTopics.aml],
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
		console.log("[Equity] address:", tokenAddress);
		console.log("[Equity] identity:", tokenIdentity);
		console.log("[Equity] access manager:", accessManager);

		// needs to be done so that he can add the claims
		await grantRole(accessManager, owner.address, SMARTRoles.claimManagerRole);
		// issue isin claim
		await issueIsinClaim(tokenIdentity, "DE000BAY0017");

		// needs supply management role to mint
		await grantRole(
			accessManager,
			owner.address,
			SMARTRoles.supplyManagementRole,
		);

		await mint(tokenAddress, 100n, 18, investorA.address);

		// TODO: execute all other functions of the equity

		return tokenAddress;
	}

	throw new Error("Failed to create equity");
};
