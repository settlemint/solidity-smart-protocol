export const SMARTTopics = {
	kyc: BigInt(1),
	aml: BigInt(2),
	collateral: BigInt(3),
	isin: BigInt(4),
} as const;

export const SMARTClaimSchemes: Record<keyof typeof SMARTTopics, string> = {
	kyc: "string claim",
	aml: "string claim",
	collateral: "uint256 amount, uint256 expiryTimestamp",
	isin: "string isin",
} as const;
