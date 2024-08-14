import { encodeFunctionData, Hex } from "viem";
import { permissionCallableAbi } from "../abi/PermissionCallable";
import { Call } from "../types";

export function preparePermissionedCall(call: Call) {
    const permissionedCall = {
        target: call.target,
        value: call.value,
        data: encodeFunctionData({
            abi: permissionCallableAbi,
            functionName: 'permissionedCall',
            args: [call.data]
        })
    };
    return permissionedCall
}