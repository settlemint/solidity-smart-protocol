import { Address, BigInt } from "@graphprotocol/graph-ts";
import { IdentityClaim } from "../../../../generated/schema";
import { fetchToken } from "../../token/fetch/token";
import { setBigNumber } from "../../utils/bignumber";
import { fetchCollateral } from "../fetch/collateral";

export function isCollateralClaim(claim: IdentityClaim): boolean {
  return claim.name === "collateral";
}

export function updateCollateral(collateralClaim: IdentityClaim): void {
  const tokenAddress = Address.fromBytes(collateralClaim.id);
  const collateral = fetchCollateral(tokenAddress);
  collateral.issuer = collateralClaim.issuer;
  const token = fetchToken(tokenAddress);
  if (collateralClaim.revoked) {
    setBigNumber(collateral, "amount", BigInt.zero(), token.decimals);
  } else {
    const values = collateralClaim.values.entries;
    for (let i = 0; i < values.length; i++) {
      const claimValue = values[i];
      if (claimValue.key === "amount") {
        setBigNumber(
          collateral,
          "amount",
          claimValue.value.toBigInt(),
          token.decimals
        );
      }
      if (claimValue.key === "expiryTimestamp") {
        collateral.expiryTimestamp = claimValue.value.toBigInt();
      }
    }
  }
  collateral.save();
}
