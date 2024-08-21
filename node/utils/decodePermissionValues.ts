import { decodeAbiParameters, Hex } from "viem";
import { PermissionValues, permissionValuesStruct } from "../types";

export function decodePermissionFields(
  permissionValues: Hex,
): PermissionValues {
  const [values] = decodeAbiParameters(
    [permissionValuesStruct],
    permissionValues,
  );

  return values;
}
