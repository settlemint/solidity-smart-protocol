import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTOnboardingModule from "../../onboarding";

const SMARTTestFundModule = buildModule("SMARTTestFundModule", (m) => {
  const { fundFactory } = m.useModule(SMARTOnboardingModule);

  const createFund = m.call(fundFactory, "createFund", [
    "Bens Bugs",
    "BB",
    8,
    20,
    "Class A",
    "Category A",
    [], // TODO: fill in with the setup for ATK
    [], // TODO: fill in with the setup for ATK
  ]);
  const fundAddress = m.readEventArgument(
    createFund,
    "TokenAssetCreated",
    "tokenAddress",
    { id: "fundAddress" }
  );
  const fundToken = m.contractAt("SMARTFundImplementation", fundAddress, {
    id: "fund",
  });

  // TODO: execute all other functions of the fund

  return {
    fundToken,
  };
});

export default SMARTTestFundModule;
