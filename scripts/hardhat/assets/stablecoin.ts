import type { Address, Hex } from "viem";
import { smartProtocolDeployer } from "../deployer";
import { claimIssuer } from "../utils/claim-issuer";
import { waitForEvent } from "../utils/wait-for-event";
import { grantClaimManagerRole } from "./actions/grant-claim-manager-role";
import { issueIsinClaim } from "./actions/issue-isin-claim";

export const createStablecoin = async () => {
	const stablecoinFactory =
		smartProtocolDeployer.getStablecoinFactoryContract();

	// TODO: typing doesn't work? Check txsigner utils
	const transactionHash: Hex = await stablecoinFactory.write.createStableCoin([
		"Tether",
		"USDT",
		6,
		[], // TODO: fill in with the setup for ATK
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
		console.log("Stablecoin address:", tokenAddress);
		console.log("Stablecoin identity:", tokenIdentity);
		console.log("Stablecoin access manager:", accessManager);

		// needs to be done so that he can add the claims
		await grantClaimManagerRole(accessManager, claimIssuer.address);
		// issue isin claim
		await issueIsinClaim(tokenIdentity, "12345678901234567890");

		// TODO: execute all other functions of the stablecoin

		return tokenAddress;
	}

	throw new Error("Failed to create deposit");
};
