// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IMarkets {
    struct MarketConfig {
        bytes32 pairId;
        address margin;
        
        bool increasePaused;
        bool decreasePaused;
        bool liquidatePaused;

        int256 precision;
        int256 feeRatio;
        int256 imRatio;
        int256 mmRatio;

        int256 multiplier;  // 1e6

        int256 minimumMargin; // 
        int256 dust;
    }

    struct Position {
        address taker;
        bytes32 marketId;
        int256 margin;
        int256 amount;
        int256 value;
        int256 fundingGrowthGlobal; // position funding growth global
        int256 unsettledFundingPayment; // unsettled funding payment
    }

    struct IncreasePositionParams {
        bytes32 marketId;
        address taker;
        bool direction;
        int256 margin;
        int256 amount;
    }

    error OnlyPools();
    error InvalidCall();
    error MarketExisted();
    error InvalidAmount();
    error InvalidMarketId();
    error PositionDanger();
    error Liquidated();
    error NotLiquidate();
    error InvalidPair();
    error InvalidMargin();
    error MarketNotExist();

    error InvalidFeeRatio();
    error InvalidIM();
    error InvalidMM();
    error InvalidDust();
    error InvalidMinimumMargin();

    error InsufficientMargin();

    error InvalidPausedStatus();
    error Paused();
    error IncreasedPaused();
    error DecreasePaused();
    error LiquidatePaused();

    error NotPosition();
    error ExcessiveMargin();


    event CreatedMarket(bytes32 marketId, address margin, bytes32 pairId, MarketConfig marketConfig);
    event UpdatedMarket(bytes32 marketId, MarketConfig config);
    event UpdatedPausedStatus(bytes32 marketId, bool addPaused, bool removePaused, bool liquidatePaused, bool globalPaused);
    event SettledFunding(bytes32 indexed marketId, address indexed taker, int256 amount, int256 fundingPayment, int256 fundingGrowthGlobal);
    event IncreasedPosition(bytes32 indexed marketId, address indexed taker, bool indexed direction, int256 margin, int256 amount, int256 value, int256 tradeFee);
    event DecreasedPosition(bytes32 indexed marketId, address indexed taker, bool indexed direction, int256 margin, int256 amount, int256 value, int256 tradeFee, int256 pnl, int256 fundingPayment);
    event LiquidatedPosition(bytes32 indexed marketId, address indexed taker, bool direction, address indexed liquidator, int256 margin, int256 amount, int256 value, int256 tradeFee, int256 pnl, int256 liquidationFee, int256 fundingPayment);
    event AddedMargin(bytes32 indexed marketId, address indexed taker, bool indexed direction, int256 amount);

    function createMarket(address margin, bytes32 pairId) external returns(bytes32 marketId);

    function increasePosition(IncreasePositionParams memory params) external returns(int256 tradeValue);
    function decreasePosition(bytes32 marketId, address taker, bool direction, int256 amount) external returns(int256 marginBalance, int256 tradeAmount, int256 tradeValue);
    function liquidate(bytes32 marketId, address taker, address liquidator, bool direction) external returns(int256 marginBalance, int256 tradeAmount, int256 tradeValue);
    function isLiquidatable(bytes32 marketId, address taker, bool direction) external view returns (bool liquidated, int256 liquidatePrice);
    function addMargin(bytes32 marketId, address taker, bool direction, int256 amount) external;

    function getMarketConfig(bytes32 marketId) external view returns(MarketConfig memory);
    function getPositionInfo(bytes32 marketId, address taker, bool direction) external view returns(Position memory);
}