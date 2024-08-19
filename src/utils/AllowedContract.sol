// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

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

    /// @notice New contract allowed for external calls
    ///
    /// @param account Account allowed to make external calls.
    /// @param permissionHash Hash of the permission.
    /// @param allowedContract Contract address for allowed external target.
    event ContractAllowed(address indexed account, bytes32 indexed permissionHash, address indexed allowedContract);

    /// @notice Get the allowed contract for a permission.
    ///
    /// @param account Account allowed to make external calls.
    /// @param permissionHash Hash of the permission.
    ///
    /// @return allowedContract Address of the contract this permission enables external calls on.
    function getAllowedContract(address account, bytes32 permissionHash) public view returns (address) {
        return _allowedContracts[permissionHash][account];
    }

    /// @notice Initialize the allowed contract for a permission.
    ///
    /// @param account Account allowed to make external calls.
    /// @param permissionHash Hash of the permission.
    /// @param allowedContract Address of the contract this permission enables external calls on.
    function _initializeAllowedContract(address account, bytes32 permissionHash, address allowedContract) internal {
        if (_allowedContracts[permissionHash][account] != address(0)) revert InitializedAllowedContract();

        _allowedContracts[permissionHash][account] = allowedContract;
        emit ContractAllowed(account, permissionHash, allowedContract);
    }
}
