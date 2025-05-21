import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ForwarderModule from "../forwarder";

const StableCoinModule = buildModule("StableCoinModule", (m) => {
  const { forwarder } = m.useModule(ForwarderModule);

  const stablecoinFactory = m.contract("SMARTStableCoinFactoryImplementation", [
    forwarder,
  ]);
  const stablecoin = m.contract("SMARTStableCoinImplementation", [forwarder]);

  return { stablecoinFactory, stablecoin };
});

export default StableCoinModule;
