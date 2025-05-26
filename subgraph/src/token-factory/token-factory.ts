import {
  TokenAssetCreated,
  TokenImplementationUpdated,
} from "../../../generated/templates/TokenFactory/TokenFactory";
import { fetchEvent } from "../event/fetch/event";

export function handleTokenAssetCreated(event: TokenAssetCreated): void {
  fetchEvent(event, "TokenAssetCreated");
}

export function handleTokenImplementationUpdated(
  event: TokenImplementationUpdated
): void {
  fetchEvent(event, "TokenImplementationUpdated");
}
