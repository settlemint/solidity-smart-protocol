import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import BondModule from "./predeployed/assets/bond";
import DepositModule from "./predeployed/assets/deposit";
import EquityModule from "./predeployed/assets/equity";
import FundModule from "./predeployed/assets/fund";
import StableCoinModule from "./predeployed/assets/stablecoin";
import SystemFactoryModule from "./predeployed/system-factory";

/**
 * This module is used to deploy the SMART contracts, this should be used to
 * bootstrap a public network. For SettleMint consortium networks this is handled
 * by predeploying in the genesis file.
 */
const SMARTModule = buildModule("SMARTModule", (m) => {
  const { systemFactory } = m.useModule(SystemFactoryModule);
  const { bond, bondFactory } = m.useModule(BondModule);
  const { deposit, depositFactory } = m.useModule(DepositModule);
  const { equity, equityFactory } = m.useModule(EquityModule);
  const { fund, fundFactory } = m.useModule(FundModule);
  const { stablecoin, stablecoinFactory } = m.useModule(StableCoinModule);

  return {
    systemFactory,
    bond,
    bondFactory,
    deposit,
    depositFactory,
    equity,
    equityFactory,
    fund,
    fundFactory,
    stablecoin,
    stablecoinFactory,
  };
});

export default SMARTModule;
