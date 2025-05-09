// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "../libraries/Plugin.sol";

contract PluginRealize is Plugin {
    uint256 public num = 1;

    function checkApprove(address user) public approved(user) returns(uint256) {
        num ++;
        return num;
    }
}