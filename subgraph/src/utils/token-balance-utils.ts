import { Token, TokenBalance } from "../../../generated/schema";
import { fetchAccount } from "../account/fetch/account";
import { setBigNumber } from "../bignumber/bignumber";
import { fetchTokenBalance } from "../token-balance/fetch/token-balance";
import { Address, BigInt, Bytes, store } from "@graphprotocol/graph-ts";

export function increaseTokenBalanceValue(
  token: Token,
  account: Address,
  value: BigInt
): void {
  const balance = fetchTokenBalance(token, fetchAccount(account));

  setBigNumber(
    balance,
    "value",
    balance.valueExact.plus(value),
    token.decimals
  );
  updateAvailableAmount(balance, token.decimals);

  balance.save();
}

export function decreaseTokenBalanceValue(
  token: Token,
  account: Address,
  value: BigInt
): void {
  const balance = fetchTokenBalance(token, fetchAccount(account));

  setBigNumber(
    balance,
    "value",
    balance.valueExact.minus(value),
    token.decimals
  );
  updateAvailableAmount(balance, token.decimals);

  balance.save();
}

export function increaseTokenBalanceFrozen(
  token: Token,
  account: Address,
  amount: BigInt
): void {
  const balance = fetchTokenBalance(token, fetchAccount(account));

  setBigNumber(
    balance,
    "frozen",
    balance.frozenExact.plus(amount),
    token.decimals
  );
  updateAvailableAmount(balance, token.decimals);

  balance.save();
}

export function decreaseTokenBalanceFrozen(
  token: Token,
  account: Address,
  amount: BigInt
): void {
  const balance = fetchTokenBalance(token, fetchAccount(account));

  setBigNumber(
    balance,
    "frozen",
    balance.frozenExact.minus(amount),
    token.decimals
  );
  updateAvailableAmount(balance, token.decimals);

  balance.save();
}

export function freezeOrUnfreezeTokenBalance(
  token: Token,
  account: Address,
  isFrozen: boolean
): void {
  const balance = fetchTokenBalance(token, fetchAccount(account));

  balance.isFrozen = isFrozen;
  updateAvailableAmount(balance, token.decimals);

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
  updateAvailableAmount(newBalance, token.decimals);

  newBalance.save();
  store.remove("TokenBalance", oldBalance.id.toHexString());
}

function updateAvailableAmount(
  tokenBalance: TokenBalance,
  decimals: number
): void {
  if (tokenBalance.isFrozen) {
    setBigNumber(tokenBalance, "available", BigInt.zero(), decimals);
  } else {
    setBigNumber(
      tokenBalance,
      "available",
      tokenBalance.valueExact.minus(tokenBalance.frozenExact),
      decimals
    );
  }
}
