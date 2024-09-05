// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PermissionCallable} from "../../src/mixins/PermissionCallable.sol";

contract MockPermissionCallable is PermissionCallable {
    function notPermissionCallable() external pure {}

    function revertNoData() external pure {
        revert();
    }

    function revertWithData(string memory data) external pure returns (bytes memory) {
        revert(data);
    }

    function successNoData() external pure {
        return;
    }

    function successWithData(bytes memory data) external pure returns (bytes memory) {
        return data;
    }

    function supportsPermissionedCallSelector(bytes4 selector) public pure override returns (bool) {
        return selector != MockPermissionCallable.notPermissionCallable.selector;
    }
}
