import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";
import { getTrustedForwarder } from "./forwarder";

const TrustedIssuersRegistryModule = buildModule(
	"TrustedIssuersRegistryModule",
	(m) => {
		// // Define the trustedForwarder parameter
		// const trustedForwarder = getTrustedForwarder(m);

		// const deployer = m.getAccount(0);

		// // Deploy implementation contract, passing the forwarder address
		// const issuersImpl = m.contract("SMARTTrustedIssuersRegistry", [
		// 	trustedForwarder,
		// ]);

		// // Deploy proxy with empty initialization data
		// const emptyInitData = "0x";
		// const issuersProxy = m.contract(
		// 	"ERC1967Proxy",
		// 	[issuersImpl, emptyInitData],
		// 	{ id: "IssuersProxy" },
		// );

		// // Get a contract instance at the proxy address
		// const trustedIssuersRegistry = m.contractAt(
		// 	"SMARTTrustedIssuersRegistry",
		// 	issuersProxy,
		// 	{ id: "IssuersAtProxyUninitialized" },
		// );

		// // Call initialize
		// m.call(trustedIssuersRegistry, "initialize", [deployer], {
		// 	id: "InitializeIssuersRegistry",
		// 	after: [issuersProxy],
		// });

		// return {
		// 	implementation: issuersImpl,
		// 	proxy: issuersProxy,
		// 	contract: trustedIssuersRegistry,
		// };

		return {};
	},
);

export default TrustedIssuersRegistryModule;
