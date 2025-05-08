import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";
import { getTrustedForwarder } from "./forwarder";

const ComplianceModule = buildModule("ComplianceModule", (m) => {
	// Define the trustedForwarder parameter
	const trustedForwarder = getTrustedForwarder(m);

	const deployer = m.getAccount(0);

	// Deploy implementation contract, passing the forwarder address
	const complianceImpl = m.contract("SMARTCompliance", [trustedForwarder]);

	// Deploy proxy with empty initialization data
	const emptyInitData = "0x";
	const complianceProxy = m.contract(
		"ERC1967Proxy",
		[complianceImpl, emptyInitData],
		{ id: "ComplianceProxy" },
	);

	// Get a contract instance at the proxy address
	const compliance = m.contractAt("SMARTCompliance", complianceProxy, {
		id: "ComplianceAtProxyUninitialized", // Renamed to reflect state
	});

	// Call initialize
	m.call(compliance, "initialize", [deployer], {
		id: "InitializeCompliance",
		after: [complianceProxy], // Ensure proxy is deployed and contractAt is available
	});

	// Return the contract instance at proxy address (now initialized)
	// We can return the same 'compliance' object as its state is effectively changed by the m.call
	// or create a new reference if strictness about future resolution timing is paramount.
	// For simplicity, reusing 'compliance' whose initialization is sequenced by 'm.call' is fine.

	return {
		implementation: complianceImpl,
		proxy: complianceProxy,
		contract: compliance, // This Future now represents an initialized contract
	};
});

export default ComplianceModule;
