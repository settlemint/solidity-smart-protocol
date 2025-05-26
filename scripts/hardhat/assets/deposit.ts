import type { Address, Hex } from "viem";
import { claimIssuer } from "../actors/claim-issuer";
import { owner } from "../actors/owner";
import { SMARTContracts } from "../constants/contracts";
import SMARTRoles from "../constants/roles";
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
		console.log("[Deposit] address:", tokenAddress);
		console.log("[Deposit] identity:", tokenIdentity);
		console.log("[Deposit] access manager:", accessManager);

		// needs to be done so that he can add the claims
		await grantRole(accessManager, owner.address, SMARTRoles.claimManagerRole);
		// issue isin claim
		await issueIsinClaim(tokenIdentity, "12345678901234567890");

		// Update collateral
		const now = new Date();
		const oneYearFromNow = new Date(
			now.getFullYear() + 1,
			now.getMonth(),
			now.getDate(),
		);
		await issueCollateralClaim(tokenIdentity, 1000n, oneYearFromNow);

		// needs supply management role to mint
		await grantRole(
			accessManager,
			owner.address,
			SMARTRoles.supplyManagementRole,
		);

		await mint(tokenAddress, 1000n, owner.address);

		// create some users with identity claims
		// mint
		// transfer
		// burn

		// TODO: execute all other functions of the deposit

		return tokenAddress;
	}

	throw new Error("Failed to create deposit");
};
