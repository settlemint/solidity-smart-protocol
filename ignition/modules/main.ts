import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ComplianceModule from "./compliance";
import ConfigurationModule from "./configuration";
import IdentityRegistryModule from "./identityRegistry";
import IdentityRegistryStorageModule from "./identityRegistryStorage";
import TrustedIssuersRegistryModule from "./trustedIssuersRegistry";

const SMARTModule = buildModule("SMARTModule", (m) => {
	console.log(`Deploying SMART contracts with account: ${m.getAccount(0)}`);

	// Use all the individual modules
	const storage = m.useModule(IdentityRegistryStorageModule);
	const issuersRegistry = m.useModule(TrustedIssuersRegistryModule);
	const compliance = m.useModule(ComplianceModule);
	const identityRegistry = m.useModule(IdentityRegistryModule);

	// Use the configuration module which handles binding
	const configuredContracts = m.useModule(ConfigurationModule);

	// Return all main contract instances for ease of use
	return {
		identityRegistry: configuredContracts.identityRegistry,
		identityRegistryStorage: configuredContracts.identityRegistryStorage,
		compliance: compliance.contract,
		trustedIssuersRegistry: issuersRegistry.contract,
	};
});

export default SMARTModule;
