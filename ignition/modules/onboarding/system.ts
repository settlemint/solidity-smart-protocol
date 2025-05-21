import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTModule from "../main";

const SMARTOnboardingSystemModule = buildModule(
  "SMARTOnboardingSystemModule",
  (m) => {
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

    m.call(system, "bootstrap");

    return {
      system,
    };
  }
);

export default SMARTOnboardingSystemModule;
