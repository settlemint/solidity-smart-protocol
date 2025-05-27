import {
  Approved,
  ClaimAdded,
  ClaimChanged,
  ClaimRemoved,
  Executed,
  ExecutionFailed,
  ExecutionRequested,
  KeyAdded,
  KeyRemoved,
} from "../../../generated/templates/TokenIdentity/TokenIdentity";
import { fetchAccount } from "../account/fetch/account";
import { fetchEvent } from "../event/fetch/event";
import { fetchTokenIdentity } from "./fetch/token-identity";
import { fetchTokenIdentityClaim } from "./fetch/token-identity-claim";

export function handleApproved(event: Approved): void {
  fetchEvent(event, "Approved");
}

export function handleClaimAdded(event: ClaimAdded): void {
  fetchEvent(event, "ClaimAdded");
  const tokenIdentity = fetchTokenIdentity(event.address);
  const tokenIdentityClaim = fetchTokenIdentityClaim(
    tokenIdentity,
    event.params.claimId
  );
  tokenIdentityClaim.topic = event.params.topic;
  tokenIdentityClaim.scheme = event.params.scheme;
  tokenIdentityClaim.issuer = fetchAccount(event.params.issuer).id;
  tokenIdentityClaim.signature = event.params.signature;
  tokenIdentityClaim.data = event.params.data;
  tokenIdentityClaim.uri = event.params.uri;

  tokenIdentityClaim.save();
}

export function handleClaimChanged(event: ClaimChanged): void {
  fetchEvent(event, "ClaimChanged");
  const tokenIdentity = fetchTokenIdentity(event.address);
  const tokenIdentityClaim = fetchTokenIdentityClaim(
    tokenIdentity,
    event.params.claimId
  );
  tokenIdentityClaim.topic = event.params.topic;
  tokenIdentityClaim.scheme = event.params.scheme;
  tokenIdentityClaim.issuer = fetchAccount(event.params.issuer).id;
  tokenIdentityClaim.signature = event.params.signature;
  tokenIdentityClaim.data = event.params.data;
  tokenIdentityClaim.uri = event.params.uri;

  tokenIdentityClaim.save();
}

export function handleClaimRemoved(event: ClaimRemoved): void {
  fetchEvent(event, "ClaimRemoved");
  const tokenIdentity = fetchTokenIdentity(event.address);
  const tokenIdentityClaim = fetchTokenIdentityClaim(
    tokenIdentity,
    event.params.claimId
  );
  tokenIdentityClaim.revoked = true;
  tokenIdentityClaim.save();
}

export function handleExecuted(event: Executed): void {
  fetchEvent(event, "Executed");
}

export function handleExecutionFailed(event: ExecutionFailed): void {
  fetchEvent(event, "ExecutionFailed");
}

export function handleExecutionRequested(event: ExecutionRequested): void {
  fetchEvent(event, "ExecutionRequested");
}

export function handleKeyAdded(event: KeyAdded): void {
  fetchEvent(event, "KeyAdded");
}

export function handleKeyRemoved(event: KeyRemoved): void {
  fetchEvent(event, "KeyRemoved");
}
