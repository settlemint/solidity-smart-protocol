import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import IdentityRegistryModule from "./identityRegistry";
import IdentityRegistryStorageModule from "./identityRegistryStorage";

const ConfigurationModule = buildModule("ConfigurationModule", (m) => {
	// Define the trustedForwarder parameter
	const trustedForwarder = m.getParameter("trustedForwarder");

	// Import dependencies. Parameters are passed implicitly.
	const { proxy: registryProxy, contract: identityRegistry } = m.useModule(
		IdentityRegistryModule,
	);
	const { contract: identityRegistryStorage } = m.useModule(
		IdentityRegistryStorageModule,
	);

	// Bind the identity registry to the storage contract
	const bindCall = m.call(
		identityRegistryStorage,
		"bindIdentityRegistry",
		[registryProxy],
		{
			id: "BindRegistryToStorage",
			after: [registryProxy], // Ensure the registry is deployed first
		},
	);

	// Return contract instances - this is required by the Ignition module system
	return {
		identityRegistry: m.contractAt("SMARTIdentityRegistry", registryProxy, {
			id: "ConfiguredIdentityRegistry",
			after: [bindCall],
		}),
		identityRegistryStorage: m.contractAt(
			"SMARTIdentityRegistryStorage",
			identityRegistryStorage.address,
			{
				id: "ConfiguredIdentityRegistryStorage",
				after: [bindCall],
			},
		),
	};
});

export default ConfigurationModule;
