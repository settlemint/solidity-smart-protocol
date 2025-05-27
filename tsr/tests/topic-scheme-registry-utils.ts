import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  TopicSchemeRegistered,
  TopicSchemeRemoved,
  TopicSchemeUpdated,
  TopicSchemesBatchRegistered
} from "../generated/TopicSchemeRegistry/TopicSchemeRegistry"

export function createTopicSchemeRegisteredEvent(
  sender: Address,
  topicId: BigInt,
  signature: string
): TopicSchemeRegistered {
  let topicSchemeRegisteredEvent =
    changetype<TopicSchemeRegistered>(newMockEvent())

  topicSchemeRegisteredEvent.parameters = new Array()

  topicSchemeRegisteredEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  topicSchemeRegisteredEvent.parameters.push(
    new ethereum.EventParam(
      "topicId",
      ethereum.Value.fromUnsignedBigInt(topicId)
    )
  )
  topicSchemeRegisteredEvent.parameters.push(
    new ethereum.EventParam("signature", ethereum.Value.fromString(signature))
  )

  return topicSchemeRegisteredEvent
}

export function createTopicSchemeRemovedEvent(
  sender: Address,
  topicId: BigInt
): TopicSchemeRemoved {
  let topicSchemeRemovedEvent = changetype<TopicSchemeRemoved>(newMockEvent())

  topicSchemeRemovedEvent.parameters = new Array()

  topicSchemeRemovedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  topicSchemeRemovedEvent.parameters.push(
    new ethereum.EventParam(
      "topicId",
      ethereum.Value.fromUnsignedBigInt(topicId)
    )
  )

  return topicSchemeRemovedEvent
}

export function createTopicSchemeUpdatedEvent(
  sender: Address,
  topicId: BigInt,
  oldSignature: string,
  newSignature: string
): TopicSchemeUpdated {
  let topicSchemeUpdatedEvent = changetype<TopicSchemeUpdated>(newMockEvent())

  topicSchemeUpdatedEvent.parameters = new Array()

  topicSchemeUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  topicSchemeUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "topicId",
      ethereum.Value.fromUnsignedBigInt(topicId)
    )
  )
  topicSchemeUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "oldSignature",
      ethereum.Value.fromString(oldSignature)
    )
  )
  topicSchemeUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newSignature",
      ethereum.Value.fromString(newSignature)
    )
  )

  return topicSchemeUpdatedEvent
}

export function createTopicSchemesBatchRegisteredEvent(
  sender: Address,
  topicIds: Array<BigInt>,
  signatures: Array<string>
): TopicSchemesBatchRegistered {
  let topicSchemesBatchRegisteredEvent =
    changetype<TopicSchemesBatchRegistered>(newMockEvent())

  topicSchemesBatchRegisteredEvent.parameters = new Array()

  topicSchemesBatchRegisteredEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  topicSchemesBatchRegisteredEvent.parameters.push(
    new ethereum.EventParam(
      "topicIds",
      ethereum.Value.fromUnsignedBigIntArray(topicIds)
    )
  )
  topicSchemesBatchRegisteredEvent.parameters.push(
    new ethereum.EventParam(
      "signatures",
      ethereum.Value.fromStringArray(signatures)
    )
  )

  return topicSchemesBatchRegisteredEvent
}
