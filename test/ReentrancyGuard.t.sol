// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// test ReentrancyGuard

import "forge-std/Test.sol";
import "../src/libraries/ReentrancyGuard.sol";

contract ReentrancyGuardTest is Test, ReentrancyGuard {
    uint256 public counter;

    function setUp() public {
        counter = 0;
    }

    function callIncr() private {
        increment(false);
    }

    function increment(bool call) public nonReentrant {
        counter += 1;
        if (call) callIncr();
    }

    function testNonReentrant() public {
        increment(false);
        assertEq(counter, 1);
        increment(false);
        assertEq(counter, 2);
    }

    function testReentrant() public {
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        this.increment(true);
    }
}