import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTOnboardingModule from "../../onboarding";
import SMARTTestDepositModule from "./deposit";
const SMARTTestBondModule = buildModule("SMARTTestBondModule", (m) => {
  const { bondFactory } = m.useModule(SMARTOnboardingModule);
  const { depositToken } = m.useModule(SMARTTestDepositModule);

  const createBond = m.call(bondFactory, "createBond", [
    "Euro Bonds",
    "EURB",
    6,
    1000000 * 10 ** 6,
    Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60, // 1 year
    123,
    depositToken,
    [], // TODO: fill in with the setup for ATK
    [], // TODO: fill in with the setup for ATK
  ]);
  const bondAddress = m.readEventArgument(
    createBond,
    "TokenAssetCreated",
    "tokenAddress",
    { id: "bondAddress" }
  );
  const bondToken = m.contractAt("SMARTBondImplementation", bondAddress, {
    id: "bond",
  });

  // TODO: add yield etc
  // TODO: execute all other functions of the bond

  return {
    bondToken,
  };
});

export default SMARTTestBondModule;
