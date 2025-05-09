// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IPools {

    struct PoolConfig {
        address asset;
        bool addPaused;
        bool removePaused;
        bool liquidatePaused;
        bytes32 pairId;
        int256 precision;
        int256 imRatio;
        int256 mmRatio;

        int256 reserveRatio;
        int256 feeRatio;
        int256 multiplier;
        int256 makerLimit; 
        int256 minimumMargin;
        int256 dust;
    }

    struct PoolStatus {
        int256 amount;
        int256 value;
        int256 margin;
    }

    struct Position {
        int256 margin;
        int256 amount;
        int256 value;
        uint256 increaseTime;
        bool initial;
    }

    struct PoolInfo {
        int256 netValue; // pool net value
        int256 indexPrice;    // index price
        int256 marketPrice;   // market price
        int256 pnl;      // unrealized pnl
        int256 fundingFee;  // new funding fee
    }

    struct TradeParams {
        bytes32 poolId;
        int256 amount;
        int256 margin;
        int256 indexPrice;
        address taker;
        bool isIncrease;
        address receiver;
        bool liquidated;
        address liquidator;
    }

    struct TradeResult {
        int256 amount;
        int256 value;
        int256 pnl;
        int256 tradeFee;
        int256 increaseFundingPayment;
        int256 settledFundingPayment;
        int256 liquidateFee;
        int256 marginBalance;
        int256 frg;
    }

    error InsufficientAmount();
    
    error InvalidCall();
    error InvalidInterval();
    error PoolExisted();
    error PoolNotExist();
    error PositionLocked(uint256 unlockTime);
    error InvalidPair();
    error InvalidAsset();
    error ErrorPrice();
    error InvalidTickConfig();
    error Liquidated();
    error Broked();

    error InvalidPausedStatus();
    error Paused();
    error AddPaused();
    error RemovePaused();
    error LiquidatePaused();

    error InvalidReserveRatio();
    error InvalidFeeRatio();
    error InvalidIM();
    error InvalidMM();
    error InvalidDust();
    error InvalidMakerLimit();

    error InsufficientMargin();
    error InsufficientLiquidity();
    error InvalidAmount();
    error PositionDanger();
    error InvalidMinimumMargin();

    error PositionLiquidated();
    error NotPosition();
    error ExcessiveMargin();
    error NotBroke();
    error Unrestorable();
    error NotLiquidate();
    error OnlyMarkets();

    error SwapPaused();

    event SetConfig(address markets, address ConfigManager, address priceHelper, address matchingEngine, address insurance, address WETH, address staker, int256 fundingCalcInterval);
    event CreatedPool(bytes32 poolId, PoolConfig config, int256 addAmount, uint8 tickConfigId);
    event UpdatedPausedStatus(bytes32 poolId, bool addPaused, bool removePaused, bool liquidatePaused, bool globalPaused);
    event UpdatedPoolConfig(bytes32 poolId, PoolConfig config);
    event AddedMargin(address maker, bytes32 poolId, int256 margin);

    event AddedLiquidity(address indexed maker, bytes32 indexed poolId, int256 amount, int256 value, int256 margin, int256 netValue);
    event RemovedLiquidity(address indexed maker, bytes32 indexed poolId, int256 amount, int256 value, int256 margin, int256 netValue, int256 pnl, int256 removeFee);
    event LiquidatedLiquidity(address indexed liquidator, address indexed maker, bytes32 indexed poolId, int256 amount, int256 value, int256 margin, int256 netValue, int256 pnl, int256 liquidateFee);

    event PoolBroked(bytes32 poolId, address trigger, int256 price);
    event PoolRestored(bytes32 poolId, address trigger);

    event Traded(bytes32 poolId, address indexed taker, bool isIncrease, int256 amount, int256 value, int256 pnl, int256 tradeFee, int256 settledFundingPayment);
    
    event UpdatedFundingRatio(bytes32 indexed poolId, int256 ratio, int256 frg, int256 unsettledFundingFee);


    function paused() external view returns(bool);
    function getPoolConfig(bytes32 poolId) external view returns(PoolConfig memory config);
    function getPosition(bytes32 poolId, address maker) external view returns(Position memory position);
    function getNetValue(bytes32 poolId) external view returns(int256);
    function getOraclePrice(bytes32 poolId) external view returns(int256 price);
    function getIndexPrice(bytes32 poolId) external view returns(int256 price);
    function getMarketPrice(bytes32 poolId, int256 indexPrice) external view returns(int256);
    function trade(TradeParams memory params) external returns(TradeResult memory result);
    function getFundingInfo(bytes32 poolId) external view returns(int256 fundingRatio, int256 frg, int256 fundingFee, int256 indexPrice);
    function updateFunding(bytes32 poolId) external returns(int256 frg);

    function getBrokeInfo(bytes32 poolId) external view returns(PoolInfo memory info);
    function isBroke(bytes32 poolId) external view returns(bool broked, int256 brokeNetValue);
    function isLiquidatable(bytes32 poolId, address maker) external view returns(bool liquidated, int256 liquidateNetValue);
    function addLiquidity(bytes32 poolId, address maker, int256 margin, int256 amount) external returns(int256 addAmount);
    function addMargin(bytes32 poolId, address maker, int256 margin) external;
    function removeLiquidity(bytes32 poolId, address maker, int256 amount, address receiver) external returns(int256 marginBalance, int256 removeAmount);
    function liquidate(bytes32 poolId, address maker, address liquidator) external returns(int256 marginBalance, int256 liquidateAmount);

    function takerAddMargin(bytes32 poolId, bool direction, int256 amount) external;

    function swapReward(address asset) external returns(uint256 inputAmount, uint256 outputAmount);
}