import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

const TrustedIssuersRegistryModule = buildModule(
	"TrustedIssuersRegistryModule",
	(m) => {
		const deployer = m.getAccount(0);

		// Deploy implementation contract
		const issuersImpl = m.contract("SMARTTrustedIssuersRegistry", []);

		// Prepare initialization data
		const issuersInterface = new ethers.Interface([
			"function initialize(address initialOwner)",
		]);
		const issuersInitData = issuersInterface.encodeFunctionData("initialize", [
			deployer, // initialOwner
		]);

		// Deploy proxy
		const issuersProxy = m.contract(
			"ERC1967Proxy",
			[issuersImpl, issuersInitData],
			{ id: "IssuersProxy" },
		);

		// Return the contract instance at proxy address
		const trustedIssuersRegistry = m.contractAt(
			"SMARTTrustedIssuersRegistry",
			issuersProxy,
			{ id: "IssuersAtProxy" },
		);

		return {
			implementation: issuersImpl,
			proxy: issuersProxy,
			contract: trustedIssuersRegistry,
		};
	},
);

export default TrustedIssuersRegistryModule;
