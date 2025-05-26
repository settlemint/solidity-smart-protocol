import {
  Bootstrapped,
  ComplianceImplementationUpdated,
  IdentityFactoryImplementationUpdated,
  IdentityImplementationUpdated,
  IdentityRegistryImplementationUpdated,
  IdentityRegistryStorageImplementationUpdated,
  TokenAccessManagerImplementationUpdated,
  TokenFactoryCreated,
  TokenIdentityImplementationUpdated,
  TrustedIssuersRegistryImplementationUpdated,
} from "../../../generated/templates/System/System";
import { fetchAccount } from "../account/fetch/account";
import { fetchEvent } from "../event/fetch/event";
import { fetchCompliance } from "./fetch/compliance";
import { fetchIdentityFactory } from "./fetch/identity-factory";
import { fetchIdentityRegistry } from "./fetch/identity-registry";
import { fetchIdentityRegistryStorage } from "./fetch/identity-registry-storage";
import { fetchSystem } from "./fetch/system";
import { fetchTrustedIssuersRegistry } from "./fetch/trusted-issuers-registry";

export function handleBootstrapped(event: Bootstrapped): void {
  fetchEvent(event, "Bootstrapped");
  const system = fetchSystem(event.address);
  system.compliance = fetchCompliance(event.params.complianceProxy).id;
  system.identityRegistry = fetchIdentityRegistry(
    event.params.identityRegistryProxy
  ).id;
  system.identityRegistryStorage = fetchIdentityRegistryStorage(
    event.params.identityRegistryStorageProxy
  ).id;
  system.trustedIssuersRegistry = fetchTrustedIssuersRegistry(
    event.params.trustedIssuersRegistryProxy
  ).id;
  system.identityFactory = fetchIdentityFactory(
    event.params.identityFactoryProxy
  ).id;
  system.save();
}

export function handleComplianceImplementationUpdated(
  event: ComplianceImplementationUpdated
): void {
  fetchEvent(event, "ComplianceImplementationUpdated");
  const compliance = fetchCompliance(event.address);
  compliance.implementation = fetchAccount(event.params.newImplementation).id;
  compliance.save();
}

export function handleIdentityFactoryImplementationUpdated(
  event: IdentityFactoryImplementationUpdated
): void {
  fetchEvent(event, "IdentityFactoryImplementationUpdated");
  const identityFactory = fetchIdentityFactory(event.address);
  identityFactory.implementation = fetchAccount(
    event.params.newImplementation
  ).id;
  identityFactory.save();
}

export function handleIdentityImplementationUpdated(
  event: IdentityImplementationUpdated
): void {
  fetchEvent(event, "IdentityImplementationUpdated");
}

export function handleIdentityRegistryImplementationUpdated(
  event: IdentityRegistryImplementationUpdated
): void {
  fetchEvent(event, "IdentityRegistryImplementationUpdated");
  const identityRegistry = fetchIdentityRegistry(event.address);
  identityRegistry.implementation = fetchAccount(
    event.params.newImplementation
  ).id;
  identityRegistry.save();
}

export function handleIdentityRegistryStorageImplementationUpdated(
  event: IdentityRegistryStorageImplementationUpdated
): void {
  fetchEvent(event, "IdentityRegistryStorageImplementationUpdated");
  const identityRegistryStorage = fetchIdentityRegistryStorage(event.address);
  identityRegistryStorage.implementation = fetchAccount(
    event.params.newImplementation
  ).id;
  identityRegistryStorage.save();
}

export function handleTokenAccessManagerImplementationUpdated(
  event: TokenAccessManagerImplementationUpdated
): void {
  fetchEvent(event, "TokenAccessManagerImplementationUpdated");
}

export function handleTokenFactoryCreated(event: TokenFactoryCreated): void {
  fetchEvent(event, "TokenFactoryCreated");
}

export function handleTokenIdentityImplementationUpdated(
  event: TokenIdentityImplementationUpdated
): void {
  fetchEvent(event, "TokenIdentityImplementationUpdated");
}

export function handleTrustedIssuersRegistryImplementationUpdated(
  event: TrustedIssuersRegistryImplementationUpdated
): void {
  fetchEvent(event, "TrustedIssuersRegistryImplementationUpdated");
}
