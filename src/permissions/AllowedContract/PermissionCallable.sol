// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

import {IPermissionCallable} from "./IPermissionCallable.sol";

/// @title PermissionCallable
///
/// @notice Abstract contract to add Session Key support.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
abstract contract PermissionCallable is IPermissionCallable {
    /// @dev Slot for the `MultiOwnableStorage` struct in storage.
    /// Computed from
    /// keccak256(abi.encode(uint256(keccak256("coinbase.storage.PermissionCallable")) - 1)) & ~bytes32(uint256(0xff))
    /// Follows ERC-7201 (see https://eips.ethereum.org/EIPS/eip-7201).
    bytes32 private constant SLOT = 0xfc8130b6d8abefc62e9245c60aaf858f44c3a4bcd3f793f1cc55690320ca5000;

    /// @notice Function does not enable calls via smart wallet permissions.
    ///
    /// @param selector function selector that was called.
    error NotPermissionCallable(bytes4 selector);

    /// @notice Enable calls via session keys.
    ///
    /// @dev If a function is called via `permissionedCall` without this modifier, will revert in that scope after call.
    modifier permissionCallable() {
        _;
        if (_isActive()) _setActive(false);
    }

    /// @notice Wrap a call to the contract with a new selector.
    ///
    /// @dev Implementing contracts are encouraged to filter selectors not appropriate for Session Key use cases.
    ///
    /// @param call Call data exactly matching an existing selector+arguments on the target contract.
    ///
    /// @return res data from self-delegatecall on other contract function.
    function permissionedCall(bytes calldata call) external payable returns (bytes memory res) {
        // activate permissioned call process
        _setActive(true);
        // make self-delegatecall with provided call data
        res = Address.functionDelegateCall(address(this), call);
        // expect call to deactivate via modifier, revert if still active
        if (_isActive()) revert NotPermissionCallable(bytes4(call));

        return res;
    }

    /// @notice Read if permissionedCall is active.
    ///
    /// @return active status of permissionedCall activation
    function _isActive() private view returns (bool active) {
        /// @solidity memory-safe-assembly
        assembly {
            active := tload(SLOT)
        }
    }

    /// @notice Read if permissionedCall is active.
    ///
    /// @param active status of permissionedCall activation
    function _setActive(bool active) private {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(SLOT, active)
        }
    }
}
