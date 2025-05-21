import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTModule from "../../main";
import SMARTOnboardingSystemModule from "../system";

const SMARTOnboardingDepositModule = buildModule(
  "SMARTOnboardingDepositModule",
  (m) => {
    const { system } = m.useModule(SMARTOnboardingSystemModule);
    const { depositFactory, deposit } = m.useModule(SMARTModule);

    const createDepositFactory = m.call(system, "createTokenFactory", [
      "deposit",
      depositFactory,
      deposit,
    ]);
    const depositFactoryAddress = m.readEventArgument(
      createDepositFactory,
      "TokenFactoryCreated",
      "proxyAddress",
      { id: "depositFactoryAddress" }
    );
    const depositFactoryProxy = m.contractAt(
      "SMARTDepositFactoryImplementation",
      depositFactoryAddress,
      {
        id: "depositFactory",
      }
    );

    return {
      depositFactory: depositFactoryProxy,
    };
  }
);

export default SMARTOnboardingDepositModule;
