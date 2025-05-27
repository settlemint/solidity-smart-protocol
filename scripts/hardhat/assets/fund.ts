import type { Address, Hex } from "viem";

import { owner } from "../actors/owner";
import { smartProtocolDeployer } from "../deployer";
import { waitForEvent } from "../utils/wait-for-event";

import { investorA } from "../actors/investors";
import SMARTRoles from "../constants/roles";
import SMARTTopics from "../constants/topics";
import { toDecimals } from "../utils/to-decimals";
import { grantRole } from "./actions/grant-role";
import { issueIsinClaim } from "./actions/issue-isin-claim";
import { mint } from "./actions/mint";

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
		[SMARTTopics.kyc, SMARTTopics.aml],
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
		await grantRole(accessManager, owner.address, SMARTRoles.claimManagerRole);
		// issue isin claim
		await issueIsinClaim(tokenIdentity, "FR0000120271");

		// needs supply management role to mint
		await grantRole(
			accessManager,
			owner.address,
			SMARTRoles.supplyManagementRole,
		);

		await mint(tokenAddress, 10n, 8, investorA.address);

		// TODO: execute all other functions of the fund

		return tokenAddress;
	}

	throw new Error("Failed to create deposit");
};
