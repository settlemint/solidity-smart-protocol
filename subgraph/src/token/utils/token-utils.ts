import { Address } from "@graphprotocol/graph-ts";
import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { fetchToken } from "../fetch/token";
import { setBigNumber } from "../../utils/bignumber";

export function increaseTokenSupply(tokenId: Bytes, amount: BigInt): void {
  const token = fetchToken(Address.fromBytes(tokenId));

  setBigNumber(
    token,
    "totalSupply",
    token.totalSupplyExact.plus(amount),
    token.decimals
  );

  token.save();
}

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
