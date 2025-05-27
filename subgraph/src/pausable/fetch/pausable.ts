import { Address } from "@graphprotocol/graph-ts";
import { TokenPausable } from "../../../../generated/schema";

export function fetchPausable(address: Address): TokenPausable {
  let pausable = TokenPausable.load(address);

  if (!pausable) {
    pausable = new TokenPausable(address);
    pausable.paused = false;
    pausable.save();
  }

  return pausable;
}
