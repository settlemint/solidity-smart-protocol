import { BurnCompleted } from "../../../generated/templates/Burnable/Burnable";
import { fetchEvent } from "../event/fetch/event";
import { fetchToken } from "../token/fetch/token";
import { decreaseTokenBalanceValue } from "../token-balance/utils/token-balance-utils";
import { decreaseTokenSupply } from "../token/utils/token-utils";

export function handleBurnCompleted(event: BurnCompleted): void {
  fetchEvent(event, "BurnCompleted");
  decreaseTokenSupply(event.address, event.params.amount);
  const token = fetchToken(event.address);
  decreaseTokenBalanceValue(token, event.params.from, event.params.amount);
}
