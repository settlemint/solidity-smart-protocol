import { BurnCompleted } from "../../../generated/templates/Burnable/Burnable";
import { fetchEvent } from "../event/fetch/event";
import { fetchToken } from "../token/fetch/token";
import { decreaseTokenBalanceValue } from "../utils/token-balance-utils";
import { decreaseTokenSupply } from "../utils/token-utils";

export function handleBurnCompleted(event: BurnCompleted): void {
  fetchEvent(event, "BurnCompleted");
  decreaseTokenSupply(event.address, event.params.amount);
  const token = fetchToken(event.address);
  decreaseTokenBalanceValue(token, event.params.from, event.params.amount);
}
