// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract ReentrancyGuard {
    bool public transient locked;

    error ReentrancyGuardReentrantCall();

    modifier nonReentrant() {
        require(!locked, ReentrancyGuardReentrantCall());
        locked = true;
        _;
        locked = false;
    }
}