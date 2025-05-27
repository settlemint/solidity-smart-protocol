import { BurnCompleted } from "../../../generated/templates/Burnable/Burnable";
import { fetchEvent } from "../event/fetch/event";
import { fetchTokenBalance } from "../token-balance/fetch/token-balance";
import { decreaseTokenBalanceValue } from "../token-balance/token-balance";
import { fetchToken } from "../token/fetch/token";

export function handleBurnCompleted(event: BurnCompleted): void {
  fetchEvent(event, "BurnCompleted");
  const token = fetchToken(event.address);
  const balance = fetchTokenBalance(token.id, event.params.from);
  decreaseTokenBalanceValue(
    token,
    event.params.from,
    balance.valueExact.minus(event.params.amount),
    event.block.timestamp
  );
}
