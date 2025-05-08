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

	// Prepare initialization data
	const registryInterface = new ethers.Interface([
		"function initialize(address initialOwner, address _identityStorage, address _issuersRegistry)",
	]);
	const registryInitData = registryInterface.encodeFunctionData("initialize", [
		deployer, // initialOwner
		storageProxy, // storage proxy address
		issuersProxy, // issuers proxy address
	]);

	// Deploy proxy
	const registryProxy = m.contract(
		"ERC1967Proxy",
		[registryImpl, registryInitData],
		{
			id: "RegistryProxy",
			after: [storageProxy, issuersProxy], // Explicit dependency
		},
	);

	// Return the contract instance at proxy address
	const identityRegistry = m.contractAt(
		"SMARTIdentityRegistry",
		registryProxy,
		{ id: "IdentityRegistryAtProxy" },
	);

	return {
		implementation: registryImpl,
		proxy: registryProxy,
		contract: identityRegistry,
	};
});

export default IdentityRegistryModule;
