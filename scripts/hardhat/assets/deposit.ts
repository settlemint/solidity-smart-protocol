import type { Address, Hex } from "viem";
import { claimIssuer } from "../actors/claim-issuer";
import { owner } from "../actors/owner";
import { smartProtocolDeployer } from "../deployer";
import { waitForEvent } from "../utils/wait-for-event";
import { grantClaimManagerRole } from "./actions/grant-claim-manager-role";
import { issueIsinClaim } from "./actions/issue-isin-claim";

export const createDeposit = async () => {
	const depositFactory = smartProtocolDeployer.getDepositFactoryContract();

	// TODO: typing doesn't work? Check txsigner utils
	const transactionHash: Hex = await depositFactory.write.createDeposit([
		"Euro Deposits",
		"EURD",
		6,
		[], // TODO: fill in with the setup for ATK
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
		console.log("Deposit address:", tokenAddress);
		console.log("Deposit identity:", tokenIdentity);
		console.log("Deposit access manager:", accessManager);

		// needs to be done so that he can add the claims
		await grantClaimManagerRole(accessManager, owner.address);
		// issue isin claim
		await issueIsinClaim(tokenIdentity, "12345678901234567890");

		// update collateral
		// create some users with identity claims
		// mint
		// transfer
		// burn

		// TODO: execute all other functions of the deposit

		return tokenAddress;
	}

	throw new Error("Failed to create deposit");
};
