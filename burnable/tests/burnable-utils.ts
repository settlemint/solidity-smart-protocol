import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import { BurnCompleted } from "../generated/Burnable/Burnable"

export function createBurnCompletedEvent(
  sender: Address,
  from: Address,
  amount: BigInt
): BurnCompleted {
  let burnCompletedEvent = changetype<BurnCompleted>(newMockEvent())

  burnCompletedEvent.parameters = new Array()

  burnCompletedEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  burnCompletedEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  burnCompletedEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return burnCompletedEvent
}
