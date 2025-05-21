import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import SMARTTestBondModule from "./test/assets/bond";
import SMARTTestDepositModule from "./test/assets/deposit";
import SMARTTestEquityModule from "./test/assets/equity";
import SMARTTestFundModule from "./test/assets/fund";
import SMARTTestStablecoinModule from "./test/assets/stablecoin";
/**
 * This module is used to deploy the SMART contracts, this should be used to
 * bootstrap a public network. For SettleMint consortium networks this is handled
 * by predeploying in the genesis file.
 */
const SMARTTestModule = buildModule("SMARTTestModule", (m) => {
  const { depositToken } = m.useModule(SMARTTestDepositModule);
  const { bondToken } = m.useModule(SMARTTestBondModule);
  const { fundToken } = m.useModule(SMARTTestFundModule);
  const { equityToken } = m.useModule(SMARTTestEquityModule);
  const { stablecoinToken } = m.useModule(SMARTTestStablecoinModule);

  return { depositToken, bondToken, fundToken, equityToken, stablecoinToken };
});

export default SMARTTestModule;
