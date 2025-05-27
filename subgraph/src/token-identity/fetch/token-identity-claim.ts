import { Bytes } from "@graphprotocol/graph-ts";
import {
  TokenIdentity,
  TokenIdentityClaim,
} from "../../../../generated/schema";

export function fetchTokenIdentityClaim(
  tokenIdentity: TokenIdentity,
  address: Bytes
): TokenIdentityClaim {
  const id = tokenIdentity.id.concat(address);
  let tokenIdentityClaim = TokenIdentityClaim.load(id);

  if (!tokenIdentityClaim) {
    tokenIdentityClaim = new TokenIdentityClaim(id);
    tokenIdentityClaim.tokenIdentity = tokenIdentity.id;
    tokenIdentityClaim.revoked = false;
    tokenIdentityClaim.save();
  }

  return tokenIdentityClaim;
}
