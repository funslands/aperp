// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "../core/interfaces/IMarkets.sol";
import "../core/interfaces/IPools.sol";

error Reentrancy(address source);
event GainsETH(address source, uint256 amount);
event FallBack(address source, uint256 amount, bytes data);
contract Trader {
    address public call;
    bytes public data;

    uint256 public value;

    function setCall(address _call, bytes memory _data) public {
        call = _call;
        data = _data;
    }

    function dos(address _call, uint256 amount, bytes memory _data) public payable returns(bool res) {
        if (amount > 0)
            (res, ) = payable(_call).call{value: amount}(_data);
        else 
            (res, ) = payable(_call).call(_data);
    }

    function gg() payable public {
        value = msg.value;
    }

    receive() external payable {
        revert("Trader Receive Attacking...");
    }

    fallback() external payable {
        revert("Trader FallBack Attacking...");
    }
}