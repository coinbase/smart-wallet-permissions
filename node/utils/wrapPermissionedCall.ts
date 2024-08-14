import { encodeFunctionData, Hex } from "viem";
import { permissionCallableAbi } from "../abi/PermissionCallable";

export function wrapPermissionedCall(callData: Hex) {
    return encodeFunctionData({
        abi: permissionCallableAbi,
        functionName: 'permissionedCall',
        args: [callData]
    })
}