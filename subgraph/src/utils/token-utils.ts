import { Address } from "@graphprotocol/graph-ts";
import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { fetchToken } from "../token/fetch/token";
import { setBigNumber } from "../bignumber/bignumber";

export function decreaseTokenSupply(tokenId: Bytes, amount: BigInt): void {
  const token = fetchToken(Address.fromBytes(tokenId));

  setBigNumber(
    token,
    "totalSupply",
    token.totalSupplyExact.minus(amount),
    token.decimals
  );

  token.save();
}
