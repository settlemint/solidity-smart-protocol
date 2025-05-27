import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts";
import { TokenBalance } from "../../../../generated/schema";
import { fetchAccount } from "../../account/fetch/account";
import { fetchToken } from "../../token/fetch/token";
import { setBigNumber } from "../../bignumber/bignumber";

export function fetchTokenBalance(
  tokenId: Bytes,
  accountAddress: Address
): TokenBalance {
  const tokenAddress = Address.fromBytes(tokenId);
  const id = tokenAddress.concat(accountAddress);

  let tokenBalance = TokenBalance.load(id);

  if (!tokenBalance) {
    tokenBalance = new TokenBalance(id);
    const token = fetchToken(tokenAddress);
    tokenBalance.token = token.id;
    tokenBalance.account = fetchAccount(accountAddress).id;
    setBigNumber(tokenBalance, "value", BigInt.fromI32(0), token.decimals);
    setBigNumber(tokenBalance, "frozen", BigInt.fromI32(0), token.decimals);
    tokenBalance.lastActivity = BigInt.fromI32(0);
    tokenBalance.save();
  }

  return tokenBalance;
}
