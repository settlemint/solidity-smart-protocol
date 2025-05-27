import { BigDecimal, BigInt, Entity } from "@graphprotocol/graph-ts";

function toDecimals(value: BigInt, decimals: number): BigDecimal {
  const precision = BigInt.fromI32(10)
    .pow(<u8>decimals)
    .toBigDecimal();
  return value.divDecimal(precision);
}

export function setBigNumber<T extends Entity>(
  entity: T,
  fieldName: keyof T,
  value: BigInt,
  decimals: number
): void {
  if (typeof fieldName === "string") {
    entity.setBigInt(fieldName.concat("Exact"), value);
    entity.setBigDecimal(fieldName, toDecimals(value, decimals));
  }
}
