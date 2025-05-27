import { BurnCompleted } from "../../../generated/templates/Burnable/Burnable";
import { fetchEvent } from "../event/fetch/event";
import { decreaseTokenBalanceValue } from "../token-balance/token-balance";
import { fetchToken } from "../token/fetch/token";

export function handleBurnCompleted(event: BurnCompleted): void {
  fetchEvent(event, "BurnCompleted");
  const token = fetchToken(event.address);
  decreaseTokenBalanceValue(
    token,
    event.params.from,
    event.params.amount,
    event.block.timestamp
  );
}
