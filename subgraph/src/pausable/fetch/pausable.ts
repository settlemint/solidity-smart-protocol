import { Address, Bytes } from "@graphprotocol/graph-ts";
import { TokenPausable } from "../../../../generated/schema";

export function fetchPausable(address: Address): TokenPausable {
  const id = address.concat(Bytes.fromUTF8("pausable"));

  let pausable = TokenPausable.load(address);

  if (!pausable) {
    pausable = new TokenPausable(id);
    pausable.paused = false;
    pausable.save();
  }

  return pausable;
}
