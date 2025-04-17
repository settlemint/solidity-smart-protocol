import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

const SMARTModule = buildModule("SMARTModule", (m) => {
	const deployer = m.getAccount(0);
	console.log(`Deploying SMART contracts with account: ${deployer}`);

	// Deploy the logic contracts first. Their constructors are now empty.
	const storageImpl = m.contract("SMARTIdentityRegistryStorage", []);
	const issuersImpl = m.contract("SMARTTrustedIssuersRegistry", []);
	const complianceImpl = m.contract("SMARTCompliance", []);
	const registryImpl = m.contract("SMARTIdentityRegistry", []);

	// --- Prepare Initialization Data ---
	// Create interfaces for encoding function data
	const storageInterface = new ethers.Interface([
		"function initialize(address initialOwner)",
	]);
	const storageInitData = storageInterface.encodeFunctionData("initialize", [
		deployer, // initialOwner
	]);

	const issuersInterface = new ethers.Interface([
		"function initialize(address initialOwner)",
	]);
	const issuersInitData = issuersInterface.encodeFunctionData("initialize", [
		deployer, // initialOwner
	]);

	const complianceInterface = new ethers.Interface([
		"function initialize(address initialOwner)",
	]);
	const complianceInitData = complianceInterface.encodeFunctionData(
		"initialize",
		[
			deployer, // initialOwner
		],
	);

	const registryInterface = new ethers.Interface([
		"function initialize(address initialOwner, address _identityStorage, address _issuersRegistry)",
	]);

	// --- Deploy Proxies ---
	// Deploy ERC1967Proxy contracts pointing to the implementations and providing initialization data.
	const storageProxyFuture = m.contract(
		"ERC1967Proxy",
		[storageImpl, storageInitData],
		{
			id: "StorageProxy", // Unique ID for the proxy deployment
		},
	);
	console.log("SMARTIdentityRegistryStorage proxy deployment declared");

	const issuersProxyFuture = m.contract(
		"ERC1967Proxy",
		[issuersImpl, issuersInitData],
		{
			id: "IssuersProxy",
		},
	);
	console.log("SMARTTrustedIssuersRegistry proxy deployment declared");

	const complianceProxyFuture = m.contract(
		"ERC1967Proxy",
		[complianceImpl, complianceInitData],
		{
			id: "ComplianceProxy",
		},
	);
	console.log("SMARTCompliance proxy deployment declared");

	// Now, prepare the registry initialization data using the Future addresses of the proxies
	const registryInitData = registryInterface.encodeFunctionData("initialize", [
		deployer, // initialOwner
		storageProxyFuture, // Future<Address> of storage proxy
		issuersProxyFuture, // Future<Address> of issuers proxy
	]);

	// Deploy the Registry Proxy, ensuring it runs after its dependencies are available
	const registryProxyFuture = m.contract(
		"ERC1967Proxy",
		[registryImpl, registryInitData],
		{
			id: "RegistryProxy",
			after: [storageProxyFuture, issuersProxyFuture], // Explicitly depend on storage and issuers proxies
		},
	);
	console.log("SMARTIdentityRegistry proxy deployment declared");

	// --- Post-Deployment Configuration ---
	// Call `bindIdentityRegistry` on the storage contract (via its proxy Future).
	// Pass the address of the registry proxy Future. Ensure this runs after the registryProxy is deployed.
	const bindCall = m.call(
		storageProxyFuture,
		"bindIdentityRegistry",
		[registryProxyFuture],
		{
			id: "BindRegistryToStorage",
			after: [registryProxyFuture], // Depends on registryProxy deployment completion
		},
	);
	console.log("bindIdentityRegistry call declared");

	// --- Return Proxied Contracts ---
	// Use m.contractAt with the proxy address Future.
	const identityRegistry = m.contractAt(
		"SMARTIdentityRegistry",
		registryProxyFuture,
		{
			id: "IdentityRegistryAtProxy",
			after: [bindCall],
		},
	);
	const compliance = m.contractAt("SMARTCompliance", complianceProxyFuture, {
		id: "ComplianceAtProxy",
	});
	const identityRegistryStorage = m.contractAt(
		"SMARTIdentityRegistryStorage",
		storageProxyFuture,
		{ id: "StorageAtProxy", after: [bindCall] },
	);
	const trustedIssuersRegistry = m.contractAt(
		"SMARTTrustedIssuersRegistry",
		issuersProxyFuture,
		{ id: "IssuersAtProxy" },
	);

	// Return the contract instances associated with the proxy addresses
	return {
		identityRegistry,
		compliance,
		identityRegistryStorage,
		trustedIssuersRegistry,
	};
});

export default SMARTModule;
