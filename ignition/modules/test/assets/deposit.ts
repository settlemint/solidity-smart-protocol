import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTOnboardingModule from "../../onboarding";

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
    { id: "depositAddress" }
  );
  const depositToken = m.contractAt(
    "SMARTDepositImplementation",
    depositAddress,
    {
      id: "deposit",
    }
  );

  // set isin on token identity
  // update collateral
  // create some users with identity claims
  // mint
  // transfer
  // burn

  // TODO: execute all other functions of the deposit

  return {
    depositToken,
  };
});

export default SMARTTestDepositModule;
