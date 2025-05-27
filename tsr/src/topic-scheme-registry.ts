import { BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
  TopicSchemeRegistry,
  TopicSchemeRegistered,
  TopicSchemeRemoved,
  TopicSchemeUpdated,
  TopicSchemesBatchRegistered
} from "../generated/TopicSchemeRegistry/TopicSchemeRegistry"
import { ExampleEntity } from "../generated/schema"

export function handleTopicSchemeRegistered(
  event: TopicSchemeRegistered
): void {
  // Entities can be loaded from the store using an ID; this ID
  // needs to be unique across all entities of the same type
  const id = event.transaction.hash.concat(
    Bytes.fromByteArray(Bytes.fromBigInt(event.logIndex))
  )
  let entity = ExampleEntity.load(id)

  // Entities only exist after they have been saved to the store;
  // `null` checks allow to create entities on demand
  if (!entity) {
    entity = new ExampleEntity(id)

    // Entity fields can be set using simple assignments
    entity.count = BigInt.fromI32(0)
  }

  // BigInt and BigDecimal math are supported
  entity.count = entity.count + BigInt.fromI32(1)

  // Entity fields can be set based on event parameters
  entity.sender = event.params.sender
  entity.topicId = event.params.topicId

  // Entities can be written to the store with `.save()`
  entity.save()

  // Note: If a handler doesn't require existing field values, it is faster
  // _not_ to load the entity from the store. Instead, create it fresh with
  // `new Entity(...)`, set the fields that should be updated and save the
  // entity back to the store. Fields that were not set or unset remain
  // unchanged, allowing for partial updates to be applied.

  // It is also possible to access smart contracts from mappings. For
  // example, the contract that has emitted the event can be connected to
  // with:
  //
  // let contract = Contract.bind(event.address)
  //
  // The following functions can then be called on this contract to access
  // state variables and other data:
  //
  // - contract.getAllTopicIds(...)
  // - contract.getTopicScheme(...)
  // - contract.getTopicSchemeCount(...)
  // - contract.getTopicSchemeSignature(...)
  // - contract.hasTopicScheme(...)
  // - contract.supportsInterface(...)
}

export function handleTopicSchemeRemoved(event: TopicSchemeRemoved): void {}

export function handleTopicSchemeUpdated(event: TopicSchemeUpdated): void {}

export function handleTopicSchemesBatchRegistered(
  event: TopicSchemesBatchRegistered
): void {}
