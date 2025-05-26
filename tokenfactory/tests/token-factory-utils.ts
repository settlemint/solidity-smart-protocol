import { newMockEvent } from "matchstick-as"
import { ethereum, Address } from "@graphprotocol/graph-ts"
import {
  TokenAssetCreated,
  TokenImplementationUpdated
} from "../generated/TokenFactory/TokenFactory"

export function createTokenAssetCreatedEvent(
  sender: Address,
  tokenAddress: Address,
  tokenIdentity: Address,
  accessManager: Address
): TokenAssetCreated {
  let tokenAssetCreatedEvent = changetype<TokenAssetCreated>(newMockEvent())

  tokenAssetCreatedEvent.parameters = new Array()

  tokenAssetCreatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  tokenAssetCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "tokenAddress",
      ethereum.Value.fromAddress(tokenAddress)
    )
  )
  tokenAssetCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "tokenIdentity",
      ethereum.Value.fromAddress(tokenIdentity)
    )
  )
  tokenAssetCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "accessManager",
      ethereum.Value.fromAddress(accessManager)
    )
  )

  return tokenAssetCreatedEvent
}

export function createTokenImplementationUpdatedEvent(
  sender: Address,
  oldImplementation: Address,
  newImplementation: Address
): TokenImplementationUpdated {
  let tokenImplementationUpdatedEvent =
    changetype<TokenImplementationUpdated>(newMockEvent())

  tokenImplementationUpdatedEvent.parameters = new Array()

  tokenImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  tokenImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "oldImplementation",
      ethereum.Value.fromAddress(oldImplementation)
    )
  )
  tokenImplementationUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newImplementation",
      ethereum.Value.fromAddress(newImplementation)
    )
  )

  return tokenImplementationUpdatedEvent
}
