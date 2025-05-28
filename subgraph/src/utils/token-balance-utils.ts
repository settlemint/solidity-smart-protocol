import { Token } from "../../../generated/schema";
import { fetchAccount } from "../account/fetch/account";
import { setBigNumber } from "../bignumber/bignumber";
import { fetchTokenBalance } from "../token-balance/fetch/token-balance";
import { Address, BigInt, store } from "@graphprotocol/graph-ts";

export function increaseTokenBalanceValue(
  token: Token,
  account: Address,
  value: BigInt
): void {
  const balance = fetchTokenBalance(token, fetchAccount(account));

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
  const balance = fetchTokenBalance(token, fetchAccount(account));

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
  const balance = fetchTokenBalance(token, fetchAccount(account));

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

export function decreaseTokenBalanceFrozen(
  token: Token,
  account: Address,
  amount: BigInt
): void {
  const balance = fetchTokenBalance(token, fetchAccount(account));

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

export function freezeOrUnfreezeTokenBalance(
  token: Token,
  account: Address,
  isFrozen: boolean
): void {
  const balance = fetchTokenBalance(token, fetchAccount(account));

  balance.isFrozen = isFrozen;
  if (isFrozen) {
    setBigNumber(balance, "available", BigInt.zero(), token.decimals);
  } else {
    setBigNumber(
      balance,
      "available",
      balance.valueExact.minus(balance.frozenExact),
      token.decimals
    );
  }

  balance.save();
}

export function moveTokenBalanceToNewAccount(
  token: Token,
  oldAccount: Address,
  newAccount: Address
): void {
  const oldBalance = fetchTokenBalance(token, fetchAccount(oldAccount));
  const newBalance = fetchTokenBalance(token, fetchAccount(newAccount));

  setBigNumber(newBalance, "value", oldBalance.valueExact, token.decimals);
  setBigNumber(newBalance, "frozen", oldBalance.frozenExact, token.decimals);
  setBigNumber(
    newBalance,
    "available",
    oldBalance.availableExact,
    token.decimals
  );

  newBalance.save();
  store.remove("TokenBalance", oldBalance.id.toHexString());
}
