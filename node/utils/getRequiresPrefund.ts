import { UserOperation } from "permissionless";
import { toBytes } from "viem";

export function getRequiredPrefund(userOp: UserOperation<"v0.6">) {
  const mul = toBytes(userOp.paymasterAndData).length === 0 ? 1 : 3;
  // sum gas parameters
  const requiredGas =
    userOp.callGasLimit +
    BigInt(mul) * userOp.verificationGasLimit +
    userOp.preVerificationGas;
  // calculate max gas fees required for prefund
  return requiredGas * userOp.maxFeePerGas;
}
