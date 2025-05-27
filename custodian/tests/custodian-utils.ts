import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  AddressFrozen,
  RecoverySuccess,
  TokensFrozen,
  TokensUnfrozen
} from "../generated/Custodian/Custodian"

export function createAddressFrozenEvent(
  sender: Address,
  userAddress: Address,
  isFrozen: boolean
): AddressFrozen {
  let addressFrozenEvent = changetype<AddressFrozen>(newMockEvent())

  addressFrozenEvent.parameters = new Array()

  addressFrozenEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  addressFrozenEvent.parameters.push(
    new ethereum.EventParam(
      "userAddress",
      ethereum.Value.fromAddress(userAddress)
    )
  )
  addressFrozenEvent.parameters.push(
    new ethereum.EventParam("isFrozen", ethereum.Value.fromBoolean(isFrozen))
  )

  return addressFrozenEvent
}

export function createRecoverySuccessEvent(
  sender: Address,
  lostWallet: Address,
  newWallet: Address,
  investorOnchainID: Address
): RecoverySuccess {
  let recoverySuccessEvent = changetype<RecoverySuccess>(newMockEvent())

  recoverySuccessEvent.parameters = new Array()

  recoverySuccessEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  recoverySuccessEvent.parameters.push(
    new ethereum.EventParam(
      "lostWallet",
      ethereum.Value.fromAddress(lostWallet)
    )
  )
  recoverySuccessEvent.parameters.push(
    new ethereum.EventParam("newWallet", ethereum.Value.fromAddress(newWallet))
  )
  recoverySuccessEvent.parameters.push(
    new ethereum.EventParam(
      "investorOnchainID",
      ethereum.Value.fromAddress(investorOnchainID)
    )
  )

  return recoverySuccessEvent
}

export function createTokensFrozenEvent(
  sender: Address,
  user: Address,
  amount: BigInt
): TokensFrozen {
  let tokensFrozenEvent = changetype<TokensFrozen>(newMockEvent())

  tokensFrozenEvent.parameters = new Array()

  tokensFrozenEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  tokensFrozenEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  tokensFrozenEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return tokensFrozenEvent
}

export function createTokensUnfrozenEvent(
  sender: Address,
  user: Address,
  amount: BigInt
): TokensUnfrozen {
  let tokensUnfrozenEvent = changetype<TokensUnfrozen>(newMockEvent())

  tokensUnfrozenEvent.parameters = new Array()

  tokensUnfrozenEvent.parameters.push(
    new ethereum.EventParam("sender", ethereum.Value.fromAddress(sender))
  )
  tokensUnfrozenEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  tokensUnfrozenEvent.parameters.push(
    new ethereum.EventParam("amount", ethereum.Value.fromUnsignedBigInt(amount))
  )

  return tokensUnfrozenEvent
}
