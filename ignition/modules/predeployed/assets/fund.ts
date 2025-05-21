import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ForwarderModule from "../forwarder";

const FundModule = buildModule("FundModule", (m) => {
  const { forwarder } = m.useModule(ForwarderModule);

  const fundFactory = m.contract("SMARTFundFactoryImplementation", [forwarder]);
  const fund = m.contract("SMARTFundImplementation", [forwarder]);

  return { fundFactory, fund };
});

export default FundModule;
