import { Address, BigInt } from "@graphprotocol/graph-ts";
import { TokenCollateral } from "../../../../generated/schema";
import { fetchToken } from "../../token/fetch/token";
import { setBigNumber } from "../../utils/bignumber";

export function fetchCollateral(address: Address): TokenCollateral {
  let collateral = TokenCollateral.load(address);

  if (!collateral) {
    collateral = new TokenCollateral(address);
    collateral.issuer = Address.zero();
    const token = fetchToken(address);
    setBigNumber(collateral, "amount", BigInt.zero(), token.decimals);
    collateral.expiryTimestamp = BigInt.fromI32(0);
    collateral.save();
  }

  return collateral;
}
