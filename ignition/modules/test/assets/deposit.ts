import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { encodeAbiParameters } from "viem";
import { parseAbiParameters } from "viem";
import { toBytes } from "viem";
import SMARTOnboardingModule from "../../onboarding";
import SMARTRoles from "../constants/roles";
import SMARTTopics from "../constants/topics";
import { createClaim } from "../utils/create-claim";

// Access ethers via the Hardhat Runtime Environment, potentially exposed by the ModuleBuilder
// This assumes 'm.hre.ethers' is available, or that 'ethers' is globally available in a way the linter should pick up.

const SMARTTestDepositModule = buildModule("SMARTTestDepositModule", (m) => {
	const { depositFactory } = m.useModule(SMARTOnboardingModule);

	const createDeposit = m.call(depositFactory, "createDeposit", [
		"Euro Deposits",
		"EURD",
		6,
		[], // TODO: fill in with the setup for ATK
		[], // TODO: fill in with the setup for ATK
	]);
	const depositAddress = m.readEventArgument(
		createDeposit,
		"TokenAssetCreated",
		"tokenAddress",
		{ id: "depositAddress" },
	);

	const depositIdentityAddress = m.readEventArgument(
		createDeposit,
		"TokenAssetCreated",
		"tokenIdentity",
		{ id: "depositIdentityAddress" },
	);

	const depositAccessManagerAddress = m.readEventArgument(
		createDeposit,
		"TokenAssetCreated",
		"accessManager",
		{ id: "depositAccessManagerAddress" },
	);

	const depositToken = m.contractAt("ISMARTDeposit", depositAddress, {
		id: "deposit",
	});

	const accessManagerContract = m.contractAt(
		"SMARTTokenAccessManagerImplementation",
		depositAccessManagerAddress,
		{ id: "accessManagerContract" },
	);

	const deployerAddress = m.getAccount(0);

	// need to have the claim manager role in order to add claims to the token identity
	m.call(accessManagerContract, "grantRole", [
		SMARTRoles.claimManagerRole,
		deployerAddress,
	]);

	const isinValue = "12345678901234567890";
	const encodedIsinData = toBytes(
		encodeAbiParameters(parseAbiParameters("string isinValue"), [isinValue]),
	);

	m.call(async ({ getAccount }) => {
		const issuerSigner = await getAccount(m.getAccount(0));

		const isinClaim = createClaim(
			issuerSigner,
			depositIdentityAddress,
			SMARTTopics.isin,
			encodedIsinData,
		);
	});

	// set isin on token identity
	// update collateral
	// create some users with identity claims
	// mint
	// transfer
	// burn

	// TODO: execute all other functions of the deposit

	return {
		depositToken,
		accessManagerContract,
	};
});

export default SMARTTestDepositModule;
