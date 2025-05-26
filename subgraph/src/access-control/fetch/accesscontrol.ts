import { Address, Bytes, Value } from "@graphprotocol/graph-ts";
import { AccessControl } from "../../../../generated/schema";
import { AccessControl as AccessControlTemplate } from "../../../../generated/templates";
import { Roles } from "../utils/role";

export function fetchAccessControl(address: Address): AccessControl {
  const id = address.concat(Bytes.fromUTF8("accesscontrol"));
  let accessControlEntity = AccessControl.load(id);

  if (!accessControlEntity) {
    accessControlEntity = new AccessControl(id);
    for (let i = 0; i < Roles.length; i++) {
      accessControlEntity.set(Roles[i].fieldName, Value.fromBytesArray([]));
    }
    accessControlEntity.save();
    AccessControlTemplate.create(address);
  }

  return accessControlEntity;
}
