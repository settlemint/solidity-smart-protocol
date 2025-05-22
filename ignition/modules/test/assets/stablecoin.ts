import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTOnboardingModule from "../../onboarding";

const SMARTTestStablecoinModule = buildModule(
	"SMARTTestStablecoinModule",
	(m) => {
		const { stablecoinFactory } = m.useModule(SMARTOnboardingModule);

		const createStableCoin = m.call(stablecoinFactory, "createStableCoin", [
			"Tether",
			"USDT",
			6,
			[], // TODO: fill in with the setup for ATK
			[], // TODO: fill in with the setup for ATK
		]);
		const stablecoinAddress = m.readEventArgument(
			createStableCoin,
			"TokenAssetCreated",
			"tokenAddress",
			{ id: "stablecoinAddress" },
		);
		const stablecoinToken = m.contractAt(
			"ISMARTStableCoin",
			stablecoinAddress,
			{
				id: "stablecoin",
			},
		);

		// TODO: execute all other functions of the stablecoin

		return {
			stablecoinToken,
		};
	},
);

export default SMARTTestStablecoinModule;
