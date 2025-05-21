import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ForwarderModule from "../forwarder";

const EquityModule = buildModule("EquityModule", (m) => {
  const { forwarder } = m.useModule(ForwarderModule);

  const equityFactory = m.contract("SMARTEquityFactoryImplementation", [
    forwarder,
  ]);
  const equity = m.contract("SMARTEquityImplementation", [forwarder]);

  return { equityFactory, equity };
});

export default EquityModule;
