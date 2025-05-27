import { Address } from "@graphprotocol/graph-ts";
import { IdentityFactory } from "../../../../generated/schema";
import { fetchAccessControl } from "../../access-control/fetch/accesscontrol";
import { fetchAccount } from "../../account/fetch/account";

export function fetchIdentityFactory(address: Address): IdentityFactory {
  let identityFactory = IdentityFactory.load(address);

  if (!identityFactory) {
    identityFactory = new IdentityFactory(address);
    identityFactory.accessControl = fetchAccessControl(address).id;
    identityFactory.account = fetchAccount(address).id;
    identityFactory.save();
    // IdentityFactoryTemplate.create(address);
  }

  return identityFactory;
}
