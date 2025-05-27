import {
  AddressFrozen,
  RecoverySuccess,
  TokensFrozen,
  TokensUnfrozen,
} from "../../../generated/templates/Custodian/Custodian";
import { fetchEvent } from "../event/fetch/event";

export function handleAddressFrozen(event: AddressFrozen): void {
  fetchEvent(event, "AddressFrozen");
}

export function handleRecoverySuccess(event: RecoverySuccess): void {
  fetchEvent(event, "RecoverySuccess");
}

export function handleTokensFrozen(event: TokensFrozen): void {
  fetchEvent(event, "TokensFrozen");
}

export function handleTokensUnfrozen(event: TokensUnfrozen): void {
  fetchEvent(event, "TokensUnfrozen");
}
