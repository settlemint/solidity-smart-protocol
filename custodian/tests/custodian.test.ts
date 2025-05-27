import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address, BigInt } from "@graphprotocol/graph-ts"
import { ExampleEntity } from "../generated/schema"
import { AddressFrozen } from "../generated/Custodian/Custodian"
import { handleAddressFrozen } from "../src/custodian"
import { createAddressFrozenEvent } from "./custodian-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/subgraphs/developing/creating/unit-testing-framework/#tests-structure

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let sender = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let userAddress = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let isFrozen = "boolean Not implemented"
    let newAddressFrozenEvent = createAddressFrozenEvent(
      sender,
      userAddress,
      isFrozen
    )
    handleAddressFrozen(newAddressFrozenEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/subgraphs/developing/creating/unit-testing-framework/#write-a-unit-test

  test("ExampleEntity created and stored", () => {
    assert.entityCount("ExampleEntity", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "ExampleEntity",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a",
      "sender",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "ExampleEntity",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a",
      "userAddress",
      "0x0000000000000000000000000000000000000001"
    )
    assert.fieldEquals(
      "ExampleEntity",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a",
      "isFrozen",
      "boolean Not implemented"
    )

    // More assert options:
    // https://thegraph.com/docs/en/subgraphs/developing/creating/unit-testing-framework/#asserts
  })
})
