// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "../core/interfaces/AggregatorV2V3Interface.sol";

contract TestOracle is AggregatorV2V3Interface {
    uint8 public override decimals = 8;
    uint80 round = 1;
    int256 price = 0;
    uint256 updateTime;
    uint256 public override version = 1;
    string public override description = "test";

    constructor(uint8 _decimals) {
        decimals = _decimals;
    }

    function updatePrice(int256 _price) public {
        round++;
        price = _price;
        updateTime = block.timestamp;
    }

    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (round, price, updateTime, updateTime, round);
    }

    function latestAnswer() external view override returns (int256) {
        return price;
    }
  
    function latestTimestamp() external view override  returns (uint256) {
        return updateTime;
    }

    function latestRound() external view override returns (uint256) {
        return round;
    }

    function getAnswer(uint256 roundId) external view override returns (int256) {
        (roundId);
        return price;
    }

    function getTimestamp(uint256 roundId) external view override returns (uint256) {
        (roundId);
        return updateTime;
    }
    
    function getRoundData(uint80 _roundId) external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        (_roundId);
        return (round, price, updateTime, updateTime, round);
    }
}