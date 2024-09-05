// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC1271} from "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import {SignatureCheckerLib as EthereumAddressSignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

contract MockPermissionSigner is IERC1271 {
    address public immutable signer;

    constructor(address signer_) {
        signer = signer_;
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
        if (EthereumAddressSignatureCheckerLib.isValidSignatureNow(signer, hash, signature)) {
            return IERC1271.isValidSignature.selector;
        }
        return 0xffffffff;
    }
}
