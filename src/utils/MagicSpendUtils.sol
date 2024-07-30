// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MagicSpend} from "magic-spend/MagicSpend.sol";

/// @title MagicSpendUtils
///
/// @notice Utilities for MagicSpend
///
/// @author Coinbase (https://github.com/coinbase/smart-wallet-periphery)
abstract contract MagicSpendUtils {
    error InvalidWithdrawToken();

    address public constant MAGIC_SPEND_ADDRESS = 0x011A61C07DbF256A68256B1cB51A5e246730aB92;

    function _isWithdrawSelector(bytes4 selector) internal pure returns (bool) {
        return selector == MagicSpend.withdraw.selector;
    }

    function _getWithdrawTransfer(bytes memory requestBytes) internal returns (address token, uint256 value) {
        MagicSpend.WithdrawRequest memory request = abi.decode(requestBytes, (MagicSpend.WithdrawRequest));
        return (request.asset, request.amount);
    }
}
