// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Governable {
    address public gov;

    error notGov();

    constructor() {
        gov = msg.sender;
    }

    modifier onlyGov() {
        require(msg.sender == gov, notGov());
        _;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
}
