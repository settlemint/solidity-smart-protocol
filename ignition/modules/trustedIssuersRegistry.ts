import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";
import { getTrustedForwarder } from "./forwarder";

const TrustedIssuersRegistryModule = buildModule(
	"TrustedIssuersRegistryModule",
	(m) => {
		// Define the trustedForwarder parameter
		const trustedForwarder = getTrustedForwarder(m);

		const deployer = m.getAccount(0);

		// Deploy implementation contract, passing the forwarder address
		const issuersImpl = m.contract("SMARTTrustedIssuersRegistry", [
			trustedForwarder,
		]);

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
