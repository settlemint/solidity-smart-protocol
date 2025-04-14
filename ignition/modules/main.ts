import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const SMARTModule = buildModule("SMARTModule", (m) => {
	const deployer = m.getAccount(0);

	const identityRegistryStorage = m.contract(
		"SMARTIdentityRegistryStorage",
		[],
		{
			id: "identityRegistryStorage",
			from: deployer,
		},
	);

	const trustedIssuersRegistry = m.contract("SMARTTrustedIssuersRegistry", [], {
		id: "trustedIssuersRegistry",
		from: deployer,
	});

	const identityRegistry = m.contract(
		"SMARTIdentityRegistry",
		[identityRegistryStorage, trustedIssuersRegistry],
		{ id: "identityRegistry", from: deployer },
	);

	const compliance = m.contract("SMARTCompliance", [], {
		id: "compliance",
		from: deployer,
	});

	return { identityRegistry, compliance };
});

export default SMARTModule;
