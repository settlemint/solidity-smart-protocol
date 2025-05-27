import { Address } from "@graphprotocol/graph-ts";
import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { fetchToken } from "./fetch/token";
import { setBigNumber } from "../bignumber/bignumber";
import { Token } from "../../../generated/schema";

export function decreaseTokenSupply(tokenId: Bytes, amount: BigInt): Token {
  const token = fetchToken(Address.fromBytes(tokenId));

  setBigNumber(
    token,
    "totalSupply",
    token.totalSupplyExact.minus(amount),
    token.decimals
  );

  token.save();

  return token;
}
