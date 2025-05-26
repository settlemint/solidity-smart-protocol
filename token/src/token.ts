import { BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
  Token,
  Approval,
  ComplianceAdded,
  ComplianceModuleAdded,
  ComplianceModuleRemoved,
  IdentityRegistryAdded,
  MintCompleted,
  ModuleParametersUpdated,
  RequiredClaimTopicsUpdated,
  Transfer,
  TransferCompleted,
  UpdatedTokenInformation
} from "../generated/Token/Token"
import { ExampleEntity } from "../generated/schema"

export function handleApproval(event: Approval): void {
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
  entity.owner = event.params.owner
  entity.spender = event.params.spender

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
  // - contract.allowance(...)
  // - contract.approve(...)
  // - contract.balanceOf(...)
  // - contract.compliance(...)
  // - contract.complianceModules(...)
  // - contract.decimals(...)
  // - contract.identityRegistry(...)
  // - contract.name(...)
  // - contract.onchainID(...)
  // - contract.requiredClaimTopics(...)
  // - contract.supportsInterface(...)
  // - contract.symbol(...)
  // - contract.totalSupply(...)
  // - contract.transfer(...)
  // - contract.transferFrom(...)
}

export function handleComplianceAdded(event: ComplianceAdded): void {}

export function handleComplianceModuleAdded(
  event: ComplianceModuleAdded
): void {}

export function handleComplianceModuleRemoved(
  event: ComplianceModuleRemoved
): void {}

export function handleIdentityRegistryAdded(
  event: IdentityRegistryAdded
): void {}

export function handleMintCompleted(event: MintCompleted): void {}

export function handleModuleParametersUpdated(
  event: ModuleParametersUpdated
): void {}

export function handleRequiredClaimTopicsUpdated(
  event: RequiredClaimTopicsUpdated
): void {}

export function handleTransfer(event: Transfer): void {}

export function handleTransferCompleted(event: TransferCompleted): void {}

export function handleUpdatedTokenInformation(
  event: UpdatedTokenInformation
): void {}
