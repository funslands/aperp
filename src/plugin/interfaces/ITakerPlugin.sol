// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "../../core/interfaces/IMarkets.sol";

interface ITakerPlugin {
    struct Order {
        int8 orderType; // 1: increase, 2: decrease, 3: tpsl
        int8 status; // -1: failed 0: pending, 1: executed, 2: canceled
        int8 triggerType; // 0: indexPrice 1: marketPrice
        OrderParams content;
        uint256 createTime;
        uint256 deadline;
    }

    struct OrderParams {
        IMarkets.IncreasePositionParams increaseParams; // margin only used for increase
        uint256 tp;
        uint256 sl;
        uint256 executionPrice;
        uint256 executionFee;
        uint256 tpSlExecutionFee; // tp/sl execution fee,only used for tpsl
    }

    struct TpSlParams {
        bytes32 marketId;
        address taker;
        bool direction;
        int8 triggerType;
        uint256 amount;
        uint256 tp;
        uint256 sl;
        uint256 deadline;
        uint256 executionFee;
    }

    error InvalidDeadline();
    error InvalidMiniExecutionFee();
    error InvalidAmount();
    error InvalidMargin();
    error InvalidExecutionFee(uint256 fee);
    error InsufficientFee();
    error NotPosition();
    error InvalidStatus(int256 status);
    error InvalidOrder();

    error NotOrder();
    error NotCancel(uint256 cancelTime);

    error TooMany();
    error NotExecute();

    error NotTrigger(int8 triggerType, uint256 triggerPrice, uint256 currentPrice);
    error NotTriggerTpSl(int8 triggerType, uint256 tp, uint256 sl, uint256 currentPrice);
    error InvalidTpSl(uint256 tp, uint256 sl);

    error BigNumber();
    error SendFail();

    event CreatedIncreaseOrder(bytes32 indexed marketId, address indexed taker, bool direction, bool isConditional, int8 triggerType, uint256 orderId, uint256 executionFee, uint256 executionPrice, uint256 deadline, int256 margin, int256 amount);
    event CreatedDecreaseOrder(bytes32 indexed marketId, address indexed taker, bool direction, bool isConditional, int8 triggerType, uint256 orderId, uint256 executionFee, uint256 executionPrice, uint256 deadline, int256 amount);
    event CreatedTpSl(bytes32 indexed marketId, address indexed taker, bool direction, int8 triggerType, uint256 amount, uint256 orderId, uint256 executionFee, uint256 deadline, uint256 tp, uint256 sl);
    event UpdatedTpSl(address indexed taker, uint256 orderId, uint256 tp, uint256 sl, uint256 deadline);
    event CanceledOrder(address indexed taker, uint256 indexed orderId, bool isConditional);
    event ExecutedOrder(bytes32 indexed marketId, address indexed executor, address indexed taker, bool isConditional, uint256 orderId, int8 orderType, uint256 executionFee, int8 triggerType, uint256 price);

    function executedOrderPosition() external view returns(uint256);
    function getOrderNum(bool isConditional) external view returns(uint256);
    function getOrderInfo(uint256 orderId, bool isConditional) external view returns(Order memory info);
    function getTakerOrders(address maker, bytes32 poolId) external view returns(uint256[] memory);
    function getTakerConditionalOrders(address maker, bytes32 poolId) external view returns(uint256[] memory);


    function createIncreaseOrder(OrderParams memory params, uint256 deadline, int8 triggerType) payable external returns(uint256 orderId, bool isConditional);
    function createDecreaseOrder(OrderParams memory params, uint256 deadline, int8 triggerType) payable external returns(uint256 orderId, bool isConditional);
    function createTpSl(TpSlParams memory params) payable external returns(uint256 orderId, bool isConditional);
    function updateTpSl(uint256 orderId, uint256 tp, uint256 sl, uint256 deadline) external;

    function addMargin(bytes32 marketId, bool direction, uint256 amount) payable external;
    function updatePriceAndLiquidatePosition(bytes32 marketId, address taker, bool direction, bytes32[] memory priceIds, bytes[] memory priceUpdateData) external payable returns(int256 marginBalance, int256 tradeAmount, int256 tradeValue);

    function cancelOrder(uint256 orderId, bool isConditional) external;
    function executeOrder(uint256 executeNum) external returns(uint8[] memory results);
    function executeConditionalOrder(uint256[] memory orderIds) external returns(uint8[] memory results);
    function updatePriceAndExecuteOrder(uint256 executeNum, bytes32[] memory priceIds, bytes[] memory priceUpdateData) payable external returns(uint8[] memory results);
    function updatePriceAndExecuteConditionalOrder(uint256[] memory ids, bytes32[] memory priceIds, bytes[] memory priceUpdateData) payable external returns(uint8[] memory results);
}