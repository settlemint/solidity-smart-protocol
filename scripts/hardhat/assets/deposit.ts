import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { encodeAbiParameters } from "viem";
import { parseAbiParameters } from "viem";
import { toBytes } from "viem";
import SMARTOnboardingModule from "../../onboarding";
import SMARTRoles from "../constants/roles";
import SMARTTopics from "../constants/topics";
import { claimIssuer } from "../utils/claim-issuer";

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

	const depositIdentityContract = m.contractAt(
		"SMARTIdentity",
		depositIdentityAddress,
		{
			id: "depositIdentity",
		},
	);

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

  const claim = await claimIssuer.createClaim(
    resolvedIdentityAddress,
    SMARTTopics.isin,
    encodedIsinData,
  );



	return {
		depositToken,
		depositIdentityContract,
		accessManagerContract,
	};
});

export default SMARTTestDepositModule;
