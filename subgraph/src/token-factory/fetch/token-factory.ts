import { Address } from "@graphprotocol/graph-ts";
import { TokenFactory } from "../../../../generated/schema";
import { TokenFactory as TokenFactoryTemplate } from "../../../../generated/templates";
import { fetchAccessControl } from "../../access-control/fetch/accesscontrol";
import { fetchAccount } from "../../account/fetch/account";

export function fetchTokenFactory(
  address: Address,
  type: string
): TokenFactory {
  let tokenFactory = TokenFactory.load(address);

  if (!tokenFactory) {
    tokenFactory = new TokenFactory(address);
    tokenFactory.accessControl = fetchAccessControl(address).id;
    tokenFactory.account = fetchAccount(address).id;
    tokenFactory.type = type;
    tokenFactory.save();
    TokenFactoryTemplate.create(address);
  }

  return tokenFactory;
}
