// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PermissionCallable} from "../../src/mixins/PermissionCallable.sol";

contract MockPermissionCallable is PermissionCallable {
    function notPermissionCallable() external {}

    function revertNoData() external {
        revert();
    }

    function revertWithData(string memory data) external returns (bytes memory) {
        revert(data);
    }

    function successNoData() external {
        return;
    }

    function successWithData(bytes memory data) external returns (bytes memory) {
        return data;
    }

    function supportsPermissionedCallSelector(bytes4 selector) public pure override returns (bool) {
        return selector != MockPermissionCallable.notPermissionCallable.selector;
    }
}
