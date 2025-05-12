// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "../../core/interfaces/IPools.sol";
import "../../core/interfaces/IPriceHelper.sol";

interface IPoolPlugin {
    struct Order {
        int8 orderType; // 1: increase, 2: decrease, 3: tpsl
        int8 status; // -1: failed 0: pending, 1: executed, 2: canceled
        OrderParams content;
        uint256 createTime;
        uint256 deadline;
    }

    struct OrderParams {
        bytes32 poolId;
        address maker;
        uint256 margin;
        uint256 amount;
        uint256 tp;
        uint256 sl;
        uint256 executionPrice;
        uint256 executionFee;
        uint256 tpSlExecutionFee; // tp/sl execution fee,only used for tpsl
    }

    struct TpSlParams {
        bytes32 poolId;
        address maker;
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

    error NotTrigger(uint256 triggerPrice, uint256 netValue);
    error NotTriggerTpSl(uint256 netValue, uint256 tp, uint256 sl);
    error InvalidTpSl(uint256 tp, uint256 sl);

    error BigNumber();
    error SendFail();

    event CreatedAddOrder(bytes32 indexed poolId, address indexed maker, bool indexed isConditional, uint256 orderId, uint256 executionFee, uint256 executionPrice, uint256 deadline, uint256 margin, uint256 amount);
    event CreatedRemoveOrder(bytes32 indexed poolId, address indexed maker, bool indexed isConditional, uint256 orderId, uint256 executionFee, uint256 executionPrice, uint256 deadline, uint256 amount);
    event CreatedTpSl(bytes32 indexed poolId, address indexed maker, uint256 amount, uint256 orderId, uint256 executionFee, uint256 deadline, uint256 tp, uint256 sl);
    event UpdatedTpSl(address indexed maker, uint256 orderId, uint256 tp, uint256 sl, uint256 deadline);
    event CanceledOrder(address indexed maker, uint256 orderId, bool isConditional);
    event ExecutedOrder(bytes32 poolId, address indexed executor, address indexed maker, bool indexed isConditional, uint256 orderId, int8 orderType, uint256 executionFee, uint256 netValue);

    function executedOrderPosition() external view returns(uint256);
    function getOrderNum(bool isConditional) external view returns(uint256);
    function getOrderInfo(uint256 orderId, bool isConditional) external view returns(Order memory info);
    function getMakerOrders(address maker, bytes32 poolId) external view returns(uint256[] memory);
    function getMakerConditionalOrders(address maker, bytes32 poolId) external view returns(uint256[] memory);
    

    function createAddOrder(OrderParams memory params, uint256 deadline) payable external returns(uint256 orderId, bool isConditional);
    function createRemoveOrder(OrderParams memory params, uint256 deadline) payable external returns(uint256 orderId, bool isConditional);
    function createTpSl(TpSlParams memory params) payable external returns(uint256 orderId, bool isConditional);
    function updateTpSl(uint256 orderId, uint256 tp, uint256 sl, uint256 deadline) external;

    function addMargin(bytes32 poolId, uint256 amount) payable external;
    function updatePriceAndLiquidateLiquidity(bytes32 poolId, address maker, bytes32[] memory priceIds, bytes[] memory priceUpdateData) external payable returns(int256 marginBalance, int256 liquidateAmount);

    function cancelOrder(uint256 orderId, bool isConditional) external;
    function executeOrder(uint256 executeNum) external returns(uint8[] memory results);
    function executeConditionalOrder(uint256[] memory orderIds) external returns(uint8[] memory results);
    function updatePriceAndExecuteOrder(uint256 executeNum, bytes32[] memory priceIds, bytes[] memory priceUpdateData) payable external returns(uint8[] memory results);
    function updatePriceAndExecuteConditionalOrder(uint256[] memory ids, bytes32[] memory priceIds, bytes[] memory priceUpdateData) payable external returns(uint8[] memory results);
}