import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const IdentityModule = buildModule("IdentityModule", (m) => {
  const identity = m.contract("SMARTIdentityImplementation");
  const tokenIdentity = m.contract("SMARTTokenIdentityImplementation");

  return { identity, tokenIdentity };
});

export default IdentityModule;
