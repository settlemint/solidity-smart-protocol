import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTModule from "../../main";

const SMARTTestDepositModule = buildModule("SMARTTestDepositModule", (m) => {
  const { depositFactory } = m.useModule(SMARTModule);

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

  // TODO: execute all other functions of the deposit

  return {
    depositToken,
  };
});

export default SMARTTestDepositModule;
