import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTOnboardingModule from "../../onboarding";

const SMARTTestEquityModule = buildModule("SMARTTestEquityModule", (m) => {
  const { equityFactory } = m.useModule(SMARTOnboardingModule);

  const createEquity = m.call(equityFactory, "createEquity", [
    "Apple",
    "AAPL",
    18,
    "Class A",
    "Category A",
    [], // TODO: fill in with the setup for ATK
    [], // TODO: fill in with the setup for ATK
  ]);
  const equityAddress = m.readEventArgument(
    createEquity,
    "TokenAssetCreated",
    "tokenAddress",
    { id: "equityAddress" }
  );
  const equityToken = m.contractAt("SMARTEquityImplementation", equityAddress, {
    id: "equity",
  });

  // TODO: execute all other functions of the equity

  return {
    equityToken,
  };
});

export default SMARTTestEquityModule;
