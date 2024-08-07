// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

import {IPermissionCallable} from "./IPermissionCallable.sol";

/// @title PermissionCallable
///
/// @notice Abstract contract to add Session Key support.
///
/// @dev Uses transient storage which requires solidity >=0.8.24 and chains to support EIP-1153
///      (https://eips.ethereum.org/EIPS/eip-1153)
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
abstract contract PermissionCallable is IPermissionCallable {
    /// @dev Slot for the `PermissionCallable` active flag in storage.
    ///      Computed from
    ///      keccak256(abi.encode(uint256(keccak256("coinbase.storage.PermissionCallable")) - 1)) &
    ///      ~bytes32(uint256(0xff))
    ///      Follows ERC-7201 (https://eips.ethereum.org/EIPS/eip-7201).
    bytes32 private constant SLOT = 0xfc8130b6d8abefc62e9245c60aaf858f44c3a4bcd3f793f1cc55690320ca5000;

    /// @notice Function does not enable calls via smart wallet permissions.
    error NotPermissionCallable();

    /// @notice Enable calls via session keys.
    ///
    /// @dev If a function is called via `permissionedCall` without this modifier, will revert in that scope after call.
    /// @dev If a function is called normally, execution proceeds undisturbed.
    modifier permissionCallable() {
        _;
        if (_isPermissionedCall()) _setCallableTriggered();
    }

    /// @notice Explicitly blocks calls via session keys.
    ///
    /// @dev OpenZeppelin's Multicall is blocked by default, so this is an additional protection.
    /// @dev Recommended to use on any function with multicall-like functionality.
    modifier blockPermissionedCalls() {
        if (_isPermissionedCall()) revert NotPermissionCallable();
        _;
    }

    /// @notice Wrap a call to the contract with a new selector.
    ///
    /// @dev Implementing contracts are required to enable selectors for permissioned calls via `permissionCallable`.
    /// @dev If call batching is desired, must do so via smart wallet, not multicall-like patterns on target contract.
    ///
    /// @param call Call data exactly matching an existing selector+arguments on the target contract.
    ///
    /// @return res data from self-delegatecall on other contract function.
    function permissionedCall(bytes calldata call) external payable returns (bytes memory res) {
        // not allowed to make permissioned calls to multicall
        // if one call in multicall batch is permission-callable, then whole batch accidentally gets allowed
        if (bytes4(call) == Multicall.multicall.selector) revert NotPermissionCallable();
        // make self-delegatecall with provided call data
        res = Address.functionDelegateCall(address(this), call);
        // expect call to activate via modifier, revert if not activated
        if (!_callableTriggered()) revert NotPermissionCallable();
        // reset transient storage for atomic permissionedCall processing
        _resetTrigger();

        return res;
    }

    /// @notice Read if permissionedCall is active.
    ///
    /// @dev Recall `msg` object will be in context of permissionedCall if active because of self-delegatecall.
    ///
    /// @return indicator if current context is within permissionedCall.
    function _isPermissionedCall() private pure returns (bool) {
        return msg.sig == PermissionCallable.permissionedCall.selector;
    }

    /// @notice Read if a permissionCallable function was triggered.
    ///
    /// @return triggered status of self-delegatecall.
    function _callableTriggered() private view returns (bool triggered) {
        /// @solidity memory-safe-assembly
        assembly {
            triggered := tload(SLOT)
        }
    }

    /// @notice Set trigger within permissionCallable function.
    ///
    /// @dev Uses transient storage for gas optimization.
    function _setCallableTriggered() private {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(SLOT, 1)
        }
    }

    /// @notice Reset trigger storage for atomic permissionedCall processing.
    ///
    /// @dev Uses transient storage for gas optimization.
    function _resetTrigger() private {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(SLOT, 0)
        }
    }
}
