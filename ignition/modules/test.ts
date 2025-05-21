import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTTestDepositModule from "./test/assets/deposit";

/**
 * This module is used to deploy the SMART contracts, this should be used to
 * bootstrap a public network. For SettleMint consortium networks this is handled
 * by predeploying in the genesis file.
 */
const SMARTTestModule = buildModule("SMARTTestModule", (m) => {
  const { depositToken } = m.useModule(SMARTTestDepositModule);

  return { depositToken };
});

export default SMARTTestModule;
