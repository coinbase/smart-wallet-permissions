// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PermissionManager} from "../PermissionManager.sol";
import {ICoinbaseSmartWallet} from "../interfaces/ICoinbaseSmartWallet.sol";
import {IMagicSpend} from "../interfaces/IMagicSpend.sol";
import {IPermissionCallable} from "../interfaces/IPermissionCallable.sol";
import {IPermissionContract} from "../interfaces/IPermissionContract.sol";
import {Bytes} from "./Bytes.sol";
import {UserOperation, UserOperationUtils} from "./UserOperationUtils.sol";

/// @title AllowedContract
///
/// @notice Supports calling a single allowed contract.
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-permissions)
abstract contract AllowedContract {
    /// @notice The only contract external calls can be made to for the permission.
    ///
    /// @dev Keying storage by account in deepest mapping enables us to pass 4337 storage access limitations.
    mapping(bytes32 permissionHash => mapping(address account => address allowedContract)) internal _allowedContracts;

    /// @notice Already initialized allowed contract
    error InitializedAllowedContract();

    event ContractAllowed(address indexed account, bytes32 indexed permissionHash, address indexed allowedContract);

    function getAllowedContract(address account, bytes32 permissionHash) public view returns (address) {
        return _allowedContracts[permissionHash][account];
    }

    function _initializeAllowedContract(address account, bytes32 permissionHash, address allowedContract) internal {
        if (_allowedContracts[permissionHash][account] != address(0)) revert InitializedAllowedContract();

        _allowedContracts[permissionHash][account] = allowedContract;
        emit ContractAllowed(account, permissionHash, allowedContract);
    }
}
