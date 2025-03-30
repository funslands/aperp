// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IMatchingEngine {
    struct TickConfig {
        int256 usageRatio;
        int256 slippage;
    }

    struct TickAmount {
        int256 usageRatio;
        int256 slippage;
        int256 amount;
    }

    struct TickStatus {
        uint256 currentTick;
        int256 makerAmount;
        int256 usageRatio;
        int256 slippage;
        int256 position;
    }

    struct MatchingParams {
        bytes32 poolId;
        int256 tradeAmount;
        int256 price;
    }

    error InvalidCall();
    error OnlyPools();
    error InvalidTickConfig();
    error InvalidConfig();
    error InvalidPool();
    error InvalidAmount();
    error LiquidityShortage(int256 tradeAmount, int256 makerAmount);

    event UpdatedPool(bytes32 poolId, TickConfig[] config);
    event UpdatedFund(bytes32 poolId, int256 amount, int256 price);


    function getStatus(bytes32 poolId) external view returns(TickStatus memory status);
    function updateFund(bytes32 poolId, int256 amount, int256 price) external returns(bool);

    function checkTickConfig(TickConfig[] memory config) external view returns(bool);
    function updateTickConfig(bytes32 poolId, TickConfig[] memory config) external;
    function matching(MatchingParams memory params) external returns(int256 amount, int256 value, int256 price);
    function getMarketPrice(bytes32 poolId, int256 price) external view returns(int256 marketPrice);
}