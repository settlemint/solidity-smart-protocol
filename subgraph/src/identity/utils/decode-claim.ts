import { BigInt, Bytes, ethereum } from "@graphprotocol/graph-ts";
import { convertEthereumValue } from "../../event/fetch/event";
import { fetchTopicScheme } from "../../topic-scheme-registry/fetch/topic-scheme";

export function decodeClaim(topicId: BigInt, data: Bytes): string {
  const topicScheme = fetchTopicScheme(topicId);

  // Parse the signature to extract parameter names and types
  const signatureWithNames = topicScheme.signature;

  // Split by comma to get individual parameters
  const params = signatureWithNames.split(",");
  const paramNames = new Array<string>();
  const paramTypes = new Array<string>();

  for (let i = 0; i < params.length; i++) {
    const param = params[i].trim();
    const spaceIndex = param.indexOf(" ");

    if (spaceIndex > 0) {
      // Has both type and name
      const type = param.substring(0, spaceIndex);
      const name = param.substring(spaceIndex + 1);
      paramTypes.push(type);
      paramNames.push(name);
    } else {
      // Only type, no name
      paramTypes.push(param);
      paramNames.push("param" + i.toString());
    }
  }

  // Create signature without parameter names for decoding
  let decodingSignature = "";

  if (paramTypes.length == 1) {
    // Single parameter - no parentheses needed
    decodingSignature = paramTypes[0];
  } else {
    // Multiple parameters - need parentheses
    decodingSignature = "(";
    for (let i = 0; i < paramTypes.length; i++) {
      if (i > 0) {
        decodingSignature = decodingSignature + ",";
      }
      decodingSignature = decodingSignature + paramTypes[i];
    }
    decodingSignature = decodingSignature + ")";
  }

  let decoded = ethereum.decode(decodingSignature, data);
  if (decoded == null) {
    return data.toHexString();
  }

  // Convert decoded value to string
  let result = "";

  if (paramTypes.length == 1) {
    // Single value - not a tuple
    const value = convertEthereumValue(decoded);
    result = "{ " + paramNames[0] + ": " + value + " }";
  } else {
    // Multiple values - decode as tuple
    const decodedTuple = decoded.toTuple();
    result = "{ ";

    for (let i = 0; i < paramNames.length; i++) {
      if (i > 0) {
        result = result + ", ";
      }
      const value = convertEthereumValue(decodedTuple[i]);
      result = result + paramNames[i] + ": " + value;
    }

    result = result + " }";
  }

  return result;
}
