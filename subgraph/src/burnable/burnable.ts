import { BurnCompleted } from "../../../generated/templates/Burnable/Burnable";
import { fetchEvent } from "../event/fetch/event";
import { decreaseTokenBalanceValue } from "../token-balance/token-balance-operations";
import { decreaseTokenSupply } from "../token/token-operations";

export function handleBurnCompleted(event: BurnCompleted): void {
  fetchEvent(event, "BurnCompleted");
  const token = decreaseTokenSupply(event.address, event.params.amount);
  decreaseTokenBalanceValue(
    token,
    event.params.from,
    event.params.amount,
    event.block.timestamp
  );
}
