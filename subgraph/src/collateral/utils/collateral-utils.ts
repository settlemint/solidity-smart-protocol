import { fetchCollateral } from "../fetch/collateral";
import { IdentityClaimValue, Token } from "../../../../generated/schema";
import { setBigNumber } from "../../utils/bignumber";
import { BigInt } from "@graphprotocol/graph-ts";

export function isCollateralClaim(claim: IdentityClaimValue): boolean {
  return claim.key === "collateral";
}

export function updateCollateral(
  token: Token,
  amount: BigInt,
  expiryTimestamp: BigInt
): void {
  const collateral = fetchCollateral(token.id);
  setBigNumber(collateral, "amount", amount, token.decimals);
  collateral.expiryTimestamp = expiryTimestamp;
  collateral.save();
}
