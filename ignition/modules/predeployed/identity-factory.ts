import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ForwarderModule from "./forwarder";

const IdentityFactoryModule = buildModule("IdentityFactoryModule", (m) => {
  const { forwarder } = m.useModule(ForwarderModule);

  const identityFactory = m.contract("SMARTIdentityFactoryImplementation", [
    forwarder,
  ]);

  return { identityFactory };
});

export default IdentityFactoryModule;
