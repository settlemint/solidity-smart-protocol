import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ForwarderModule from "../forwarder";

const BondModule = buildModule("BondModule", (m) => {
  const { forwarder } = m.useModule(ForwarderModule);

  const bondFactory = m.contract("SMARTBondFactoryImplementation", [forwarder]);
  const bond = m.contract("SMARTBondImplementation", [forwarder]);

  return { bondFactory, bond };
});

export default BondModule;
