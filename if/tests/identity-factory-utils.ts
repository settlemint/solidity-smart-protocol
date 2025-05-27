import { newMockEvent } from "matchstick-as"
import { ethereum, Address } from "@graphprotocol/graph-ts"
import {
  IdentityCreated,
  TokenIdentityCreated
} from "../generated/IdentityFactory/IdentityFactory"

export function createIdentityCreatedEvent(
  sender: Address,
  identity: Address,
  wallet: Address
): IdentityCreated {
  let identityCreatedEvent = changetype<IdentityCreated>(newMockEvent())

  identityCreatedEvent.parameters = new Array()

  identityCreatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  identityCreatedEvent.parameters.push(
    new ethereum.EventParam("identity", ethereum.Value.fromAddress(identity))
  )
  identityCreatedEvent.parameters.push(
    new ethereum.EventParam("wallet", ethereum.Value.fromAddress(wallet))
  )

  return identityCreatedEvent
}

export function createTokenIdentityCreatedEvent(
  sender: Address,
  identity: Address,
  token: Address
): TokenIdentityCreated {
  let tokenIdentityCreatedEvent =
    changetype<TokenIdentityCreated>(newMockEvent())

  tokenIdentityCreatedEvent.parameters = new Array()

  tokenIdentityCreatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  tokenIdentityCreatedEvent.parameters.push(
    new ethereum.EventParam("identity", ethereum.Value.fromAddress(identity))
  )
  tokenIdentityCreatedEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )

  return tokenIdentityCreatedEvent
}
