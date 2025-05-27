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

export const createDeposit = async () => {
	const depositFactory = smartProtocolDeployer.getDepositFactoryContract();

	// TODO: typing doesn't work? Check txsigner utils
	const transactionHash: Hex = await depositFactory.write.createDeposit([
		"Euro Deposits",
		"EURD",
		6,
		[SMARTTopics.kyc, SMARTTopics.aml],
		[], // TODO: fill in with the setup for ATK
	]);

	const { tokenAddress, tokenIdentity, accessManager } = (await waitForEvent({
		transactionHash,
		contract: depositFactory,
		eventName: "TokenAssetCreated",
	})) as unknown as {
		sender: Address;
		tokenAddress: Address;
		tokenIdentity: Address;
		accessManager: Address;
	};

	if (tokenAddress && tokenIdentity && accessManager) {
		console.log("[Deposit] address:", tokenAddress);
		console.log("[Deposit] identity:", tokenIdentity);
		console.log("[Deposit] access manager:", accessManager);

		// needs to be done so that he can add the claims
		await grantRole(accessManager, owner.address, SMARTRoles.claimManagerRole);
		// issue isin claim
		await issueIsinClaim(tokenIdentity, "US1234567890");

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

		// create some users with identity claims
		// mint
		// transfer
		// burn

		// TODO: execute all other functions of the deposit

		return tokenAddress;
	}

	throw new Error("Failed to create deposit");
};
