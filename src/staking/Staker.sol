// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./interfaces/IStaker.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract Staker is IStaker {
    address public WETH;

    constructor(address _WETH) {
        WETH = _WETH;
    }

    function addReward(uint256 amount) public override {
        SafeERC20.safeTransferFrom(IERC20(WETH), msg.sender, address(this), amount);
    }
}