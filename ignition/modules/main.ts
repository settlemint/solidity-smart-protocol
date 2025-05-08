import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import ComplianceModule from "./compliance";
import ConfigurationModule from "./configuration";
import IdentityRegistryModule from "./identityRegistry";
import IdentityRegistryStorageModule from "./identityRegistryStorage";
import TrustedIssuersRegistryModule from "./trustedIssuersRegistry";

const SMARTModule = buildModule("SMARTModule", (m) => {
	// Define the trustedForwarder parameter
	const trustedForwarder = m.getParameter(
		"trustedForwarder",
		"0x0000000000000000000000000000000000000000",
	);

	console.log(`Deploying SMART contracts with account: ${m.getAccount(0)}`);
	console.log(`Using trusted forwarder: ${trustedForwarder}`);

	// Use all the individual modules. Parameters are passed implicitly.
	const storage = m.useModule(IdentityRegistryStorageModule);
	const issuersRegistry = m.useModule(TrustedIssuersRegistryModule);
	const compliance = m.useModule(ComplianceModule);
	// IdentityRegistryModule is used indirectly via ConfigurationModule now

	// Use the configuration module which handles binding.
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
