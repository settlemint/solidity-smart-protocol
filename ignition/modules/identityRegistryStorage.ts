import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

const IdentityRegistryStorageModule = buildModule(
	"IdentityRegistryStorageModule",
	(m) => {
		// // Define the trustedForwarder parameter
		// const trustedForwarder = m.getParameter(
		// 	"trustedForwarder",
		// 	"0x0000000000000000000000000000000000000000",
		// );

		// const deployer = m.getAccount(0);

		// // Deploy implementation contract, passing the forwarder address
		// const storageImpl = m.contract("SMARTIdentityRegistryStorage", [
		// 	trustedForwarder,
		// ]);

		// // Deploy proxy with empty initialization data
		// const emptyInitData = "0x";
		// const storageProxy = m.contract(
		// 	"ERC1967Proxy",
		// 	[storageImpl, emptyInitData],
		// 	{ id: "StorageProxy" },
		// );

		// // Get a contract instance at the proxy address
		// const identityRegistryStorage = m.contractAt(
		// 	"SMARTIdentityRegistryStorage",
		// 	storageProxy,
		// 	{ id: "StorageAtProxyUninitialized" },
		// );

		// // Call initialize
		// m.call(identityRegistryStorage, "initialize", [deployer], {
		// 	id: "InitializeStorage",
		// 	after: [storageProxy],
		// });

		// return {
		// 	implementation: storageImpl,
		// 	proxy: storageProxy,
		// 	contract: identityRegistryStorage,
		// };
		return {};
	},
);

export default IdentityRegistryStorageModule;
