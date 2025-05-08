import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";
import { getTrustedForwarder } from "./forwarder";
import IdentityRegistryStorageModule from "./identityRegistryStorage";
import TrustedIssuersRegistryModule from "./trustedIssuersRegistry";

const IdentityRegistryModule = buildModule("IdentityRegistryModule", (m) => {
	// Define the trustedForwarder parameter
	const trustedForwarder = getTrustedForwarder(m);

	const deployer = m.getAccount(0);

	// Import dependencies. Parameters are passed implicitly.
	const { proxy: storageProxy } = m.useModule(IdentityRegistryStorageModule);
	const { proxy: issuersProxy } = m.useModule(TrustedIssuersRegistryModule);

	// Deploy implementation contract, passing the forwarder address
	const registryImpl = m.contract("SMARTIdentityRegistry", [trustedForwarder]);

	// Deploy proxy with empty initialization data
	const emptyInitData = "0x";
	const registryProxy = m.contract(
		"ERC1967Proxy",
		[registryImpl, emptyInitData],
		{
			id: "RegistryProxy",
			after: [storageProxy, issuersProxy], // Explicit dependency for proxy deployment
		},
	);

	// Get a contract instance at the proxy address
	const identityRegistry = m.contractAt(
		"SMARTIdentityRegistry",
		registryProxy,
		{ id: "IdentityRegistryAtProxyUninitialized" },
	);

	// Call initialize with deployer, storageProxy, and issuersProxy
	// All these are Futures and will be resolved by m.call
	m.call(
		identityRegistry,
		"initialize",
		[deployer, storageProxy, issuersProxy],
		{
			id: "InitializeIdentityRegistry",
			// Ensure proxy is deployed, and dependencies for args (storageProxy, issuersProxy) are also met.
			// `after` on `registryProxy` already covers storageProxy and issuersProxy for its own deployment.
			// `m.call` will wait for `identityRegistry` (which depends on `registryProxy`) and its arguments.
			after: [registryProxy], // Or simply identityRegistry which implies registryProxy
		},
	);

	return {
		implementation: registryImpl,
		proxy: registryProxy,
		contract: identityRegistry, // This Future now represents an initialized contract
	};
});

export default IdentityRegistryModule;
