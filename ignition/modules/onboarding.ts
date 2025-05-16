import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTModule from "./main";

/**
 * This module is used to deploy the SMART contracts, this should be used to
 * bootstrap a public network. For SettleMint consortium networks this is handled
 * by predeploying in the genesis file.
 */
const SMARTOnboardingModule = buildModule("SMARTOnboardingModule", (m) => {
  const { systemFactory } = m.useModule(SMARTModule);

  const createSystem = m.call(systemFactory, "createSystem");
  const systemAddress = m.readEventArgument(
    createSystem,
    "SMARTSystemCreated",
    "systemAddress",
    { id: "systemAddress" }
  );
  const system = m.contractAt("SMARTSystem", systemAddress, {
    id: "system",
  });

  return {
    system,
  };
});

export default SMARTOnboardingModule;
