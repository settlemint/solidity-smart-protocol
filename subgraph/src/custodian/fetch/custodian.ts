import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts";
import { TokenCustodian } from "../../../../generated/schema";
import { setBigNumber } from "../../bignumber/bignumber";
import { fetchToken } from "../../token/fetch/token";

export function fetchCustodian(address: Address): TokenCustodian {
  const id = address.concat(Bytes.fromUTF8("custodian"));

  let custodian = TokenCustodian.load(id);

  if (!custodian) {
    custodian = new TokenCustodian(id);
    const token = fetchToken(address);
    setBigNumber(custodian, "frozen", BigInt.fromI32(0), token.decimals);
    custodian.save();
  }

  return custodian;
}
