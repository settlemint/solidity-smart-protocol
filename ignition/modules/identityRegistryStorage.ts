import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

const IdentityRegistryStorageModule = buildModule(
	"IdentityRegistryStorageModule",
	(m) => {
		const deployer = m.getAccount(0);

		// Deploy implementation contract
		const storageImpl = m.contract("SMARTIdentityRegistryStorage", []);

		// Prepare initialization data
		const storageInterface = new ethers.Interface([
			"function initialize(address initialOwner)",
		]);
		const storageInitData = storageInterface.encodeFunctionData("initialize", [
			deployer, // initialOwner
		]);

		// Deploy proxy
		const storageProxy = m.contract(
			"ERC1967Proxy",
			[storageImpl, storageInitData],
			{ id: "StorageProxy" },
		);

		// Return the contract instance at proxy address
		const identityRegistryStorage = m.contractAt(
			"SMARTIdentityRegistryStorage",
			storageProxy,
			{ id: "StorageAtProxy" },
		);

		return {
			implementation: storageImpl,
			proxy: storageProxy,
			contract: identityRegistryStorage,
		};
	},
);

export default IdentityRegistryStorageModule;
