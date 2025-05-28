import { Token } from "../../../generated/schema";
import { setBigNumber } from "../bignumber/bignumber";
import { fetchTokenBalance } from "../token-balance/fetch/token-balance";
import { Address, BigInt, store } from "@graphprotocol/graph-ts";

export function increaseTokenBalanceValue(
  token: Token,
  account: Address,
  value: BigInt
): void {
  const balance = fetchTokenBalance(Address.fromBytes(token.id), account);

  const newValue = balance.valueExact.plus(value);
  setBigNumber(balance, "value", newValue, token.decimals);
  setBigNumber(
    balance,
    "available",
    newValue.minus(balance.frozenExact),
    token.decimals
  );

  balance.save();
}

export function decreaseTokenBalanceValue(
  token: Token,
  account: Address,
  value: BigInt
): void {
  const balance = fetchTokenBalance(Address.fromBytes(token.id), account);

  const newValue = balance.valueExact.minus(value);
  setBigNumber(balance, "value", newValue, token.decimals);
  setBigNumber(
    balance,
    "available",
    newValue.minus(balance.frozenExact),
    token.decimals
  );

  balance.save();
}

export function increaseTokenBalanceFrozen(
  token: Token,
  account: Address,
  amount: BigInt
): void {
  const balance = fetchTokenBalance(Address.fromBytes(token.id), account);

  const newFrozen = balance.frozenExact.plus(amount);
  setBigNumber(balance, "frozen", newFrozen, token.decimals);
  setBigNumber(
    balance,
    "available",
    balance.valueExact.minus(newFrozen),
    token.decimals
  );

  balance.save();
}

export function updateTokenBalanceFrozen(
  token: Token,
  account: Address,
  newBalance: BigInt
): void {
  const balance = fetchTokenBalance(Address.fromBytes(token.id), account);

  setBigNumber(balance, "frozen", newBalance, token.decimals);
  setBigNumber(
    balance,
    "available",
    balance.valueExact.minus(newBalance),
    token.decimals
  );

  balance.save();
}

export function decreaseTokenBalanceFrozen(
  token: Token,
  account: Address,
  amount: BigInt
): void {
  const balance = fetchTokenBalance(Address.fromBytes(token.id), account);

  const newFrozen = balance.frozenExact.minus(amount);
  setBigNumber(balance, "frozen", newFrozen, token.decimals);
  setBigNumber(
    balance,
    "available",
    balance.valueExact.minus(newFrozen),
    token.decimals
  );

  balance.save();
}

export function moveTokenBalanceToNewAccount(
  token: Token,
  oldAccount: Address,
  newAccount: Address
): void {
  const tokenAddress = Address.fromBytes(token.id);
  const oldBalance = fetchTokenBalance(tokenAddress, oldAccount);
  const newBalance = fetchTokenBalance(tokenAddress, newAccount);

  setBigNumber(newBalance, "value", oldBalance.valueExact, token.decimals);
  setBigNumber(newBalance, "frozen", oldBalance.frozenExact, token.decimals);

  newBalance.save();
  store.remove("TokenBalance", oldBalance.id.toHexString());
}
