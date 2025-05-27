import type { Address, Hex } from "viem";

import { owner } from "../actors/owner";
import { smartProtocolDeployer } from "../deployer";
import { waitForEvent } from "../utils/wait-for-event";

import { investorA } from "../actors/investors";
import { SMARTRoles } from "../constants/roles";
import { SMARTTopics } from "../constants/topics";
import { grantRole } from "./actions/grant-role";
import { issueCollateralClaim } from "./actions/issue-collateral-claim";
import { issueIsinClaim } from "./actions/issue-isin-claim";
import { mint } from "./actions/mint";

export const createStablecoin = async () => {
	const stablecoinFactory =
		smartProtocolDeployer.getStablecoinFactoryContract();

	// TODO: typing doesn't work? Check txsigner utils
	const transactionHash: Hex = await stablecoinFactory.write.createStableCoin([
		"Tether",
		"USDT",
		6,
		[SMARTTopics.kyc, SMARTTopics.aml],
		[], // TODO: fill in with the setup for ATK
	]);

	const { tokenAddress, tokenIdentity, accessManager } = (await waitForEvent({
		transactionHash,
		contract: stablecoinFactory,
		eventName: "TokenAssetCreated",
	})) as unknown as {
		sender: Address;
		tokenAddress: Address;
		tokenIdentity: Address;
		accessManager: Address;
	};

	if (tokenAddress && tokenIdentity && accessManager) {
		console.log("[Stablecoin] address:", tokenAddress);
		console.log("[Stablecoin] identity:", tokenIdentity);
		console.log("[Stablecoin] access manager:", accessManager);

		// needs to be done so that he can add the claims
		await grantRole(accessManager, owner.address, SMARTRoles.claimManagerRole);
		// issue isin claim
		await issueIsinClaim(tokenIdentity, "JP3902900004");

		// Update collateral
		const now = new Date();
		const oneYearFromNow = new Date(
			now.getFullYear() + 1,
			now.getMonth(),
			now.getDate(),
		);
		await issueCollateralClaim(tokenIdentity, 1000n, 6, oneYearFromNow);

		// needs supply management role to mint
		await grantRole(
			accessManager,
			owner.address,
			SMARTRoles.supplyManagementRole,
		);

		await mint(tokenAddress, 1000n, 6, investorA.address);

		// TODO: execute all other functions of the stablecoin

		return tokenAddress;
	}

	throw new Error("Failed to create deposit");
};
