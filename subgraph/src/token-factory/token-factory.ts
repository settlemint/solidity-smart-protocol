import {
  TokenAssetCreated,
  TokenImplementationUpdated,
} from "../../../generated/templates/TokenFactory/TokenFactory";
import { fetchEvent } from "../event/fetch/event";
import { fetchTokenIdentity } from "../token-identity/fetch/token-identity";
import { fetchToken } from "../token/fetch/token";
import { fetchTokenFactory } from "./fetch/token-factory";

export function handleTokenAssetCreated(event: TokenAssetCreated): void {
  fetchEvent(event, "TokenAssetCreated");
  const tokenFactory = fetchTokenFactory(event.address);
  const token = fetchToken(event.params.tokenAddress);
  token.tokenFactory = tokenFactory.id;
  token.type = tokenFactory.type;
  token.identity = fetchTokenIdentity(event.params.tokenIdentity).id;
  token.save();
}

export function handleTokenImplementationUpdated(
  event: TokenImplementationUpdated
): void {
  fetchEvent(event, "TokenImplementationUpdated");
}
