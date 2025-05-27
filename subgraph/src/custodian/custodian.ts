import {
  AddressFrozen,
  RecoverySuccess,
  TokensFrozen,
  TokensUnfrozen,
} from "../../../generated/templates/Custodian/Custodian";
import { fetchEvent } from "../event/fetch/event";
import { fetchCustodian } from "./fetch/custodian";
import { setBigNumber } from "../bignumber/bignumber";
import { fetchToken } from "../token/fetch/token";
import {
  decreaseTokenBalanceFrozen,
  increaseTokenBalanceFrozen,
  updateTokenBalanceFrozen,
  moveTokenBalanceToNewAccount,
} from "../token-balance/token-balance-operations";
import { Custodian as CustodianContract } from "../../../generated/templates/Custodian/Custodian";
import { fetchTokenBalance } from "../token-balance/fetch/token-balance";

export function handleAddressFrozen(event: AddressFrozen): void {
  fetchEvent(event, "AddressFrozen");
  const token = fetchToken(event.address);

  const custodianContract = CustodianContract.bind(event.address);

  if (event.params.isFrozen) {
    const balance = fetchTokenBalance(token.id, event.params.userAddress);
    updateTokenBalanceFrozen(
      token,
      event.params.userAddress,
      balance.valueExact,
      event.block.timestamp
    );
  } else {
    const frozenTokens = custodianContract.getFrozenTokens(
      event.params.userAddress
    );
    updateTokenBalanceFrozen(
      token,
      event.params.userAddress,
      frozenTokens,
      event.block.timestamp
    );
  }
}

export function handleRecoverySuccess(event: RecoverySuccess): void {
  fetchEvent(event, "RecoverySuccess");
  const token = fetchToken(event.address);
  moveTokenBalanceToNewAccount(
    token,
    event.params.lostWallet,
    event.params.newWallet,
    event.block.timestamp
  );
}

export function handleTokensFrozen(event: TokensFrozen): void {
  fetchEvent(event, "TokensFrozen");
  const custodian = fetchCustodian(event.address);
  const token = fetchToken(event.address);
  increaseTokenBalanceFrozen(
    token,
    event.params.user,
    event.params.amount,
    event.block.timestamp
  );
  const updatedAmount = custodian.totalFrozenExact.plus(event.params.amount);
  setBigNumber(custodian, "frozen", updatedAmount, token.decimals);
  custodian.save();
}

export function handleTokensUnfrozen(event: TokensUnfrozen): void {
  fetchEvent(event, "TokensUnfrozen");
  const custodian = fetchCustodian(event.address);
  const token = fetchToken(event.address);
  decreaseTokenBalanceFrozen(
    token,
    event.params.user,
    event.params.amount,
    event.block.timestamp
  );
  const updatedAmount = custodian.totalFrozenExact.minus(event.params.amount);
  setBigNumber(custodian, "frozen", updatedAmount, token.decimals);
  custodian.save();
}
