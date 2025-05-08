import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";
import { getTrustedForwarder } from "./forwarder";

const ComplianceModule = buildModule("ComplianceModule", (m) => {
	// Define the trustedForwarder parameter
	const trustedForwarder = getTrustedForwarder(m);

	const deployer = m.getAccount(0);

	// Deploy implementation contract, passing the forwarder address
	const complianceImpl = m.contract("SMARTCompliance", [trustedForwarder]);

	// Prepare initialization data
	const complianceInterface = new ethers.Interface([
		"function initialize(address initialOwner)",
	]);
	const complianceInitData = complianceInterface.encodeFunctionData(
		"initialize",
		[
			deployer, // initialOwner
		],
	);

	// Deploy proxy
	const complianceProxy = m.contract(
		"ERC1967Proxy",
		[complianceImpl, complianceInitData],
		{ id: "ComplianceProxy" },
	);

	// Return the contract instance at proxy address
	const compliance = m.contractAt("SMARTCompliance", complianceProxy, {
		id: "ComplianceAtProxy",
	});

	return {
		implementation: complianceImpl,
		proxy: complianceProxy,
		contract: compliance,
	};
});

export default ComplianceModule;
