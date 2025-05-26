import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
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

export function createApprovalEvent(
  owner: Address,
  spender: Address,
  value: BigInt
): Approval {
  let approvalEvent = changetype<Approval>(newMockEvent())

  approvalEvent.parameters = new Array()

  approvalEvent.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("spender", ethereum.Value.fromAddress(spender))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return approvalEvent
}

export function createComplianceAddedEvent(
  sender: Address,
  _compliance: Address
): ComplianceAdded {
  let complianceAddedEvent = changetype<ComplianceAdded>(newMockEvent())

  complianceAddedEvent.parameters = new Array()

  complianceAddedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  complianceAddedEvent.parameters.push(
    new ethereum.EventParam(
      "_compliance",
      ethereum.Value.fromAddress(_compliance)
    )
  )

  return complianceAddedEvent
}

export function createComplianceModuleAddedEvent(
  sender: Address,
  _module: Address,
  _params: Bytes
): ComplianceModuleAdded {
  let complianceModuleAddedEvent =
    changetype<ComplianceModuleAdded>(newMockEvent())

  complianceModuleAddedEvent.parameters = new Array()

  complianceModuleAddedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  complianceModuleAddedEvent.parameters.push(
    new ethereum.EventParam("_module", ethereum.Value.fromAddress(_module))
  )
  complianceModuleAddedEvent.parameters.push(
    new ethereum.EventParam("_params", ethereum.Value.fromBytes(_params))
  )

  return complianceModuleAddedEvent
}

export function createComplianceModuleRemovedEvent(
  sender: Address,
  _module: Address
): ComplianceModuleRemoved {
  let complianceModuleRemovedEvent =
    changetype<ComplianceModuleRemoved>(newMockEvent())

  complianceModuleRemovedEvent.parameters = new Array()

  complianceModuleRemovedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  complianceModuleRemovedEvent.parameters.push(
    new ethereum.EventParam("_module", ethereum.Value.fromAddress(_module))
  )

  return complianceModuleRemovedEvent
}

export function createIdentityRegistryAddedEvent(
  sender: Address,
  _identityRegistry: Address
): IdentityRegistryAdded {
  let identityRegistryAddedEvent =
    changetype<IdentityRegistryAdded>(newMockEvent())

  identityRegistryAddedEvent.parameters = new Array()

  identityRegistryAddedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  identityRegistryAddedEvent.parameters.push(
    new ethereum.EventParam(
      "_identityRegistry",
      ethereum.Value.fromAddress(_identityRegistry)
    )
  )

  return identityRegistryAddedEvent
}

export function createMintCompletedEvent(
  sender: Address,
  to: Address,
  amount: BigInt
): MintCompleted {
  let mintCompletedEvent = changetype<MintCompleted>(newMockEvent())

  mintCompletedEvent.parameters = new Array()

  mintCompletedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  mintCompletedEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  mintCompletedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return mintCompletedEvent
}

export function createModuleParametersUpdatedEvent(
  sender: Address,
  _module: Address,
  _params: Bytes
): ModuleParametersUpdated {
  let moduleParametersUpdatedEvent =
    changetype<ModuleParametersUpdated>(newMockEvent())

  moduleParametersUpdatedEvent.parameters = new Array()

  moduleParametersUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  moduleParametersUpdatedEvent.parameters.push(
    new ethereum.EventParam("_module", ethereum.Value.fromAddress(_module))
  )
  moduleParametersUpdatedEvent.parameters.push(
    new ethereum.EventParam("_params", ethereum.Value.fromBytes(_params))
  )

  return moduleParametersUpdatedEvent
}

export function createRequiredClaimTopicsUpdatedEvent(
  sender: Address,
  _requiredClaimTopics: Array<BigInt>
): RequiredClaimTopicsUpdated {
  let requiredClaimTopicsUpdatedEvent =
    changetype<RequiredClaimTopicsUpdated>(newMockEvent())

  requiredClaimTopicsUpdatedEvent.parameters = new Array()

  requiredClaimTopicsUpdatedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  requiredClaimTopicsUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "_requiredClaimTopics",
      ethereum.Value.fromUnsignedBigIntArray(_requiredClaimTopics)
    )
  )

  return requiredClaimTopicsUpdatedEvent
}

export function createTransferEvent(
  from: Address,
  to: Address,
  value: BigInt
): Transfer {
  let transferEvent = changetype<Transfer>(newMockEvent())

  transferEvent.parameters = new Array()

  transferEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return transferEvent
}

export function createTransferCompletedEvent(
  sender: Address,
  from: Address,
  to: Address,
  amount: BigInt
): TransferCompleted {
  let transferCompletedEvent = changetype<TransferCompleted>(newMockEvent())

  transferCompletedEvent.parameters = new Array()

  transferCompletedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  transferCompletedEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  transferCompletedEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  transferCompletedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return transferCompletedEvent
}

export function createUpdatedTokenInformationEvent(
  sender: Address,
  _newDecimals: i32,
  _newOnchainID: Address
): UpdatedTokenInformation {
  let updatedTokenInformationEvent =
    changetype<UpdatedTokenInformation>(newMockEvent())

  updatedTokenInformationEvent.parameters = new Array()

  updatedTokenInformationEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  updatedTokenInformationEvent.parameters.push(
    new ethereum.EventParam(
      "_newDecimals",
      ethereum.Value.fromUnsignedBigInt(BigInt.fromI32(_newDecimals))
    )
  )
  updatedTokenInformationEvent.parameters.push(
    new ethereum.EventParam(
      "_newOnchainID",
      ethereum.Value.fromAddress(_newOnchainID)
    )
  )

  return updatedTokenInformationEvent
}
