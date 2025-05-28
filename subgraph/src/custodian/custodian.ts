import {
  AddressFrozen,
  RecoverySuccess,
  TokensFrozen,
  TokensUnfrozen,
} from "../../../generated/templates/Custodian/Custodian";
import { fetchEvent } from "../event/fetch/event";
import { fetchToken } from "../token/fetch/token";
import {
  decreaseTokenBalanceFrozen,
  increaseTokenBalanceFrozen,
  updateTokenBalanceFrozen,
  moveTokenBalanceToNewAccount,
} from "../utils/token-balance-utils";
import { Custodian as CustodianContract } from "../../../generated/templates/Custodian/Custodian";
import { fetchTokenBalance } from "../token-balance/fetch/token-balance";

export function handleAddressFrozen(event: AddressFrozen): void {
  fetchEvent(event, "AddressFrozen");
  const token = fetchToken(event.address);

  if (event.params.isFrozen) {
    // If an address is frozen, set the total frozen amount to the balance value
    const balance = fetchTokenBalance(event.address, event.params.userAddress);
    updateTokenBalanceFrozen(
      token,
      event.params.userAddress,
      balance.valueExact
    );
  } else {
    const custodianContract = CustodianContract.bind(event.address);

    // Restore the original frozen amount from the custodian contract
    const frozenTokens = custodianContract.getFrozenTokens(
      event.params.userAddress
    );
    updateTokenBalanceFrozen(token, event.params.userAddress, frozenTokens);
  }
}

export function handleRecoverySuccess(event: RecoverySuccess): void {
  fetchEvent(event, "RecoverySuccess");
  const token = fetchToken(event.address);
  moveTokenBalanceToNewAccount(
    token,
    event.params.lostWallet,
    event.params.newWallet
  );
}

export function handleTokensFrozen(event: TokensFrozen): void {
  fetchEvent(event, "TokensFrozen");
  const token = fetchToken(event.address);
  increaseTokenBalanceFrozen(token, event.params.user, event.params.amount);
}

export function handleTokensUnfrozen(event: TokensUnfrozen): void {
  fetchEvent(event, "TokensUnfrozen");
  const token = fetchToken(event.address);
  decreaseTokenBalanceFrozen(token, event.params.user, event.params.amount);
}
