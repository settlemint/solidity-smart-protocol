import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
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
  TrustedIssuersRegistryImplementationUpdated
} from "../generated/System/System"

export function createBootstrappedEvent(
  sender: Address,
  complianceProxy: Address,
  identityRegistryProxy: Address,
  identityRegistryStorageProxy: Address,
  trustedIssuersRegistryProxy: Address,
  identityFactoryProxy: Address
): Bootstrapped {
  let bootstrappedEvent = changetype<Bootstrapped>(newMockEvent())

  bootstrappedEvent.parameters = new Array()

  bootstrappedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  bootstrappedEvent.parameters.push(
    new ethereum.EventParam(
      "complianceProxy",
      ethereum.Value.fromAddress(complianceProxy)
    )
  )
  bootstrappedEvent.parameters.push(
    new ethereum.EventParam(
      "identityRegistryProxy",
      ethereum.Value.fromAddress(identityRegistryProxy)
    )
  )
  bootstrappedEvent.parameters.push(
    new ethereum.EventParam(
      "identityRegistryStorageProxy",
      ethereum.Value.fromAddress(identityRegistryStorageProxy)
    )
  )
  bootstrappedEvent.parameters.push(
    new ethereum.EventParam(
      "trustedIssuersRegistryProxy",
      ethereum.Value.fromAddress(trustedIssuersRegistryProxy)
    )
  )
  bootstrappedEvent.parameters.push(
    new ethereum.EventParam(
      "identityFactoryProxy",
      ethereum.Value.fromAddress(identityFactoryProxy)
    )
  )

  return bootstrappedEvent
}

export function createComplianceImplementationUpdatedEvent(
  sender: Address,
  newImplementation: Address
): ComplianceImplementationUpdated {
  let complianceImplementationUpdatedEvent =
    changetype<ComplianceImplementationUpdated>(newMockEvent())

  complianceImplementationUpdatedEvent.parameters = new Array()

  complianceImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  complianceImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newImplementation",
      ethereum.Value.fromAddress(newImplementation)
    )
  )

  return complianceImplementationUpdatedEvent
}

export function createIdentityFactoryImplementationUpdatedEvent(
  sender: Address,
  newImplementation: Address
): IdentityFactoryImplementationUpdated {
  let identityFactoryImplementationUpdatedEvent =
    changetype<IdentityFactoryImplementationUpdated>(newMockEvent())

  identityFactoryImplementationUpdatedEvent.parameters = new Array()

  identityFactoryImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  identityFactoryImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newImplementation",
      ethereum.Value.fromAddress(newImplementation)
    )
  )

  return identityFactoryImplementationUpdatedEvent
}

export function createIdentityImplementationUpdatedEvent(
  sender: Address,
  newImplementation: Address
): IdentityImplementationUpdated {
  let identityImplementationUpdatedEvent =
    changetype<IdentityImplementationUpdated>(newMockEvent())

  identityImplementationUpdatedEvent.parameters = new Array()

  identityImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  identityImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newImplementation",
      ethereum.Value.fromAddress(newImplementation)
    )
  )

  return identityImplementationUpdatedEvent
}

export function createIdentityRegistryImplementationUpdatedEvent(
  sender: Address,
  newImplementation: Address
): IdentityRegistryImplementationUpdated {
  let identityRegistryImplementationUpdatedEvent =
    changetype<IdentityRegistryImplementationUpdated>(newMockEvent())

  identityRegistryImplementationUpdatedEvent.parameters = new Array()

  identityRegistryImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  identityRegistryImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newImplementation",
      ethereum.Value.fromAddress(newImplementation)
    )
  )

  return identityRegistryImplementationUpdatedEvent
}

export function createIdentityRegistryStorageImplementationUpdatedEvent(
  sender: Address,
  newImplementation: Address
): IdentityRegistryStorageImplementationUpdated {
  let identityRegistryStorageImplementationUpdatedEvent =
    changetype<IdentityRegistryStorageImplementationUpdated>(newMockEvent())

  identityRegistryStorageImplementationUpdatedEvent.parameters = new Array()

  identityRegistryStorageImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  identityRegistryStorageImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newImplementation",
      ethereum.Value.fromAddress(newImplementation)
    )
  )

  return identityRegistryStorageImplementationUpdatedEvent
}

export function createTokenAccessManagerImplementationUpdatedEvent(
  sender: Address,
  newImplementation: Address
): TokenAccessManagerImplementationUpdated {
  let tokenAccessManagerImplementationUpdatedEvent =
    changetype<TokenAccessManagerImplementationUpdated>(newMockEvent())

  tokenAccessManagerImplementationUpdatedEvent.parameters = new Array()

  tokenAccessManagerImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  tokenAccessManagerImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newImplementation",
      ethereum.Value.fromAddress(newImplementation)
    )
  )

  return tokenAccessManagerImplementationUpdatedEvent
}

export function createTokenFactoryCreatedEvent(
  sender: Address,
  typeName: string,
  proxyAddress: Address,
  implementationAddress: Address,
  timestamp: BigInt
): TokenFactoryCreated {
  let tokenFactoryCreatedEvent = changetype<TokenFactoryCreated>(newMockEvent())

  tokenFactoryCreatedEvent.parameters = new Array()

  tokenFactoryCreatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  tokenFactoryCreatedEvent.parameters.push(
    new ethereum.EventParam("typeName", ethereum.Value.fromString(typeName))
  )
  tokenFactoryCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "proxyAddress",
      ethereum.Value.fromAddress(proxyAddress)
    )
  )
  tokenFactoryCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "implementationAddress",
      ethereum.Value.fromAddress(implementationAddress)
    )
  )
  tokenFactoryCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )

  return tokenFactoryCreatedEvent
}

export function createTokenIdentityImplementationUpdatedEvent(
  sender: Address,
  newImplementation: Address
): TokenIdentityImplementationUpdated {
  let tokenIdentityImplementationUpdatedEvent =
    changetype<TokenIdentityImplementationUpdated>(newMockEvent())

  tokenIdentityImplementationUpdatedEvent.parameters = new Array()

  tokenIdentityImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  tokenIdentityImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newImplementation",
      ethereum.Value.fromAddress(newImplementation)
    )
  )

  return tokenIdentityImplementationUpdatedEvent
}

export function createTrustedIssuersRegistryImplementationUpdatedEvent(
  sender: Address,
  newImplementation: Address
): TrustedIssuersRegistryImplementationUpdated {
  let trustedIssuersRegistryImplementationUpdatedEvent =
    changetype<TrustedIssuersRegistryImplementationUpdated>(newMockEvent())

  trustedIssuersRegistryImplementationUpdatedEvent.parameters = new Array()

  trustedIssuersRegistryImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  trustedIssuersRegistryImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newImplementation",
      ethereum.Value.fromAddress(newImplementation)
    )
  )

  return trustedIssuersRegistryImplementationUpdatedEvent
}
