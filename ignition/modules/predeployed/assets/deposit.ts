import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ForwarderModule from "../forwarder";

const DepositModule = buildModule("DepositModule", (m) => {
  const { forwarder } = m.useModule(ForwarderModule);

  const depositFactory = m.contract("SMARTDepositFactoryImplementation", [
    forwarder,
  ]);
  const deposit = m.contract("SMARTDepositImplementation", [forwarder]);

  return { depositFactory, deposit };
});

export default DepositModule;
