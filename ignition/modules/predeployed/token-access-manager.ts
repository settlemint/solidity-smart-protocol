import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ForwarderModule from "./forwarder";

const TokenAccessManagerModule = buildModule(
  "TokenAccessManagerModule",
  (m) => {
    const { forwarder } = m.useModule(ForwarderModule);

    const tokenAccessManager = m.contract(
      "SMARTTokenAccessManagerImplementation",
      [forwarder]
    );

    return { tokenAccessManager };
  }
);

export default TokenAccessManagerModule;
