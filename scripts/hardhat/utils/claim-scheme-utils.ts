import {
	type Hex,
	decodeAbiParameters,
	encodeAbiParameters,
	parseAbiParameters,
} from "viem";
import { SMARTClaimSchemes, SMARTTopics } from "../constants/topics";

/**
 * Maps a claim topic bigint to its corresponding scheme string for ABI encoding/decoding
 * @param claimTopic The claim topic as a bigint (e.g., SMARTTopics.kyc)
 * @returns The ABI parameter scheme string (e.g., "string claim")
 * @throws Error if the claim topic is not found
 */
export function getClaimScheme(claimTopic: bigint): string {
	// Create a reverse mapping from topic values to keys
	const topicToKey: Record<string, keyof typeof SMARTTopics> = {};

	for (const [key, value] of Object.entries(SMARTTopics)) {
		topicToKey[value.toString()] = key as keyof typeof SMARTTopics;
	}

	const topicKey = topicToKey[claimTopic.toString()];

	if (!topicKey) {
		throw new Error(`Unknown claim topic: ${claimTopic}`);
	}

	return SMARTClaimSchemes[topicKey];
}

/**
 * Gets the ABI parameter types for encoding claim data
 * @param claimTopic The claim topic as a bigint
 * @returns The parameter types string for parseAbiParameters
 */
export function getClaimParameterTypes(claimTopic: bigint): string {
	const scheme = getClaimScheme(claimTopic);
	return scheme;
}

/**
 * Decodes claim data based on the claim topic's scheme
 * @param claimTopic The claim topic as a bigint
 * @param encodedData The encoded claim data as hex string
 * @returns The decoded claim data
 */
export function decodeClaimData(
	claimTopic: bigint,
	encodedData: Hex,
): readonly unknown[] {
	const parameterTypes = getClaimParameterTypes(claimTopic);
	return decodeAbiParameters(parseAbiParameters(parameterTypes), encodedData);
}

/**
 * Gets the topic key name from a claim topic bigint
 * @param claimTopic The claim topic as a bigint
 * @returns The topic key name (e.g., "kyc", "aml", "collateral", "isin")
 */
export function getTopicKeyName(claimTopic: bigint): keyof typeof SMARTTopics {
	// Create a reverse mapping from topic values to keys
	const topicToKey: Record<string, keyof typeof SMARTTopics> = {};

	for (const [key, value] of Object.entries(SMARTTopics)) {
		topicToKey[value.toString()] = key as keyof typeof SMARTTopics;
	}

	const topicKey = topicToKey[claimTopic.toString()];

	if (!topicKey) {
		throw new Error(`Unknown claim topic: ${claimTopic}`);
	}

	return topicKey;
}

/**
 * Encodes claim data based on the claim topic's scheme
 * @param claimTopic The claim topic as a bigint
 * @param values The values to encode according to the claim scheme
 * @returns The encoded claim data as hex string
 */
export function encodeClaimData(
	claimTopic: bigint,
	values: readonly unknown[],
): Hex {
	const parameterTypes = getClaimParameterTypes(claimTopic);
	return encodeAbiParameters(parseAbiParameters(parameterTypes), values);
}

/**
 * Type-safe helper for decoding collateral claim data
 * @param encodedData The encoded collateral claim data
 * @returns Object with amount and expiryTimestamp
 */
export function decodeCollateralClaimData(encodedData: Hex): {
	amount: bigint;
	expiryTimestamp: bigint;
} {
	const [amount, expiryTimestamp] = decodeClaimData(
		SMARTTopics.collateral,
		encodedData,
	);
	return {
		amount: amount as bigint,
		expiryTimestamp: expiryTimestamp as bigint,
	};
}
