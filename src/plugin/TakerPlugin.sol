// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./interfaces/ITakerPlugin.sol";
import "../core/interfaces/IMarkets.sol";
import "../core/interfaces/IPools.sol";
import "../core/interfaces/IPriceHelper.sol";
import "./interfaces/IWETH.sol";
import "../libraries/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract TakerPlugin is ITakerPlugin, ReentrancyGuard {
    address immutable wETH;
    address public immutable pools;
    address public immutable markets;
    address public immutable priceHelper;
    uint256 public immutable minimumExecutionFee;
    
    uint256 public override executedOrderPosition;
    Order[] private orders;
    Order[] private conditionalOrders;

    // taker => marketId => orderId
    mapping(address=> mapping(bytes32=>uint256[])) private takerOrders;
    mapping(address=> mapping(bytes32=>uint256[])) private takerConditionalOrders;

    receive() external payable { }

    constructor(address _wETH, address _pools, address _markets, address _priceHelper, uint256 _minimumExecutionFee) {
        require(_minimumExecutionFee >= 0.000001 ether && _minimumExecutionFee <= 0.01 ether, InvalidMiniExecutionFee());
        wETH = _wETH;
        pools = _pools;
        markets = _markets;
        priceHelper = _priceHelper;
        minimumExecutionFee = _minimumExecutionFee;
    }

    function getOrderInfo(uint256 orderId, bool isConditional) external override view returns(Order memory info) {
        orderId -= 1;
        info = isConditional ? conditionalOrders[orderId] : orders[orderId];
    }

    function getOrderNum(bool isConditional) external view override returns(uint256) {
        return isConditional ? conditionalOrders.length : orders.length;
    }

    function getTakerOrders(address taker, bytes32 marketId) external view returns(uint256[] memory) {
        return takerOrders[taker][marketId];
    }
    function getTakerConditionalOrders(address taker, bytes32 marketId) external view returns(uint256[] memory) {
        return takerConditionalOrders[taker][marketId];
    }

    function createIncreaseOrder(OrderParams memory params, uint256 deadline, int8 triggerType) payable external override nonReentrant returns(uint256 orderId, bool isConditional) {
        require(deadline >= block.timestamp + 300, InvalidDeadline());
        require(params.executionFee >= minimumExecutionFee, InvalidExecutionFee(params.executionFee));
        if (params.tp > 0 || params.sl > 0) {
            if (params.increaseParams.direction) {
                if (params.tp == 0) params.tp = 1e28;
                require(params.tp > params.sl, InvalidTpSl(params.tp, params.sl));
            }
            else {
                if (params.sl == 0) params.sl = 1e28;
                require(params.sl > params.tp, InvalidTpSl(params.tp, params.sl));
            }
            require(params.tpSlExecutionFee >= minimumExecutionFee, InvalidExecutionFee(params.tpSlExecutionFee));
        }
        else {
            params.tpSlExecutionFee = 0;
        }

        uint256 execFee = params.executionFee + params.tpSlExecutionFee;

        IMarkets.IncreasePositionParams memory orderParams = params.increaseParams;
        IMarkets.MarketConfig memory marketConfig = IMarkets(markets).getMarketConfig(orderParams.marketId);

        require(orderParams.amount >= marketConfig.dust, InvalidAmount());
        require(orderParams.margin >= marketConfig.minimumMargin, InvalidMargin());
        

        // transfer margin
        address marginToken = marketConfig.margin;
        if (marginToken == wETH && msg.value > execFee) {
            require(msg.value == execFee + uint256(orderParams.margin), InsufficientFee());
            IWETH(wETH).deposit{value: uint256(orderParams.margin)}();
        } else {
            require(msg.value == execFee, InsufficientFee());
            SafeERC20.safeTransferFrom(IERC20(marginToken), msg.sender, address(this), uint256(orderParams.margin));
        }

        if (orderParams.taker != msg.sender) orderParams.taker = msg.sender;

        (orderId, isConditional) = createOrder(1, triggerType, orderParams.marketId, deadline, params.executionPrice, params);

        emit CreatedIncreaseOrder(orderParams.marketId, orderParams.taker, orderParams.direction, isConditional, triggerType, orderId, params.executionFee, params.executionPrice, deadline, orderParams.margin, orderParams.amount);
    }

    function createDecreaseOrder(OrderParams memory params, uint256 deadline, int8 triggerType) payable external override nonReentrant returns (uint256 orderId, bool isConditional) {
        require(deadline >= block.timestamp + 300, InvalidDeadline());

        IMarkets.IncreasePositionParams memory orderParams = params.increaseParams;
        require(orderParams.amount > 0, InvalidAmount());

        require(params.executionFee >= minimumExecutionFee, InvalidExecutionFee(params.executionFee));
        require(msg.value == params.executionFee, InsufficientFee());

        if (orderParams.taker != msg.sender) orderParams.taker = msg.sender;
        IMarkets.Position memory position = IMarkets(markets).getPositionInfo(orderParams.marketId, orderParams.taker, orderParams.direction);
        require(position.amount != 0, NotPosition());

        (orderId, isConditional) = createOrder(2, triggerType, orderParams.marketId, deadline, params.executionPrice, params);

        emit CreatedDecreaseOrder(orderParams.marketId, orderParams.taker, orderParams.direction, isConditional, triggerType, orderId, msg.value, params.executionPrice, deadline, orderParams.amount);
    }

    function createTpSl(TpSlParams memory params) payable public override nonReentrant returns(uint256 orderId, bool isConditional) {
        require(params.deadline >= block.timestamp + 300, InvalidDeadline());
        require(params.executionFee >= minimumExecutionFee, InvalidExecutionFee(params.executionFee));
        require(msg.value == params.executionFee, InsufficientFee());
        if (params.taker != msg.sender) params.taker = msg.sender;
        (orderId, isConditional) = _createTpSl(params);
    }
    function _createTpSl(TpSlParams memory params) private returns(uint256 orderId, bool isConditional) {
        require(params.tp > 0 || params.sl > 0, InvalidTpSl(params.tp, params.sl));
        if (params.direction) {
            if (params.tp == 0) params.tp = 1e28;
            require(params.tp > params.sl, InvalidTpSl(params.tp, params.sl));
        }
        else {
            if (params.sl == 0) params.sl = 1e28;
            require(params.sl > params.tp, InvalidTpSl(params.tp, params.sl));
        }


        IMarkets.Position memory position = IMarkets(markets).getPositionInfo(params.marketId, params.taker, params.direction);
        require(position.amount != 0, NotPosition());
        

        IMarkets.IncreasePositionParams memory increaseParams = IMarkets.IncreasePositionParams({
            marketId: params.marketId,
            taker: params.taker,
            direction: params.direction,
            margin: 0,
            amount: toInt256(params.amount)
        });

        OrderParams memory orderParams = OrderParams({
            increaseParams: increaseParams,
            tp: params.tp,
            sl: params.sl,
            executionPrice: 0,
            executionFee: params.executionFee,
            tpSlExecutionFee: 0
        });

        Order memory order = Order({
            orderType: 3,
            status: 0,
            triggerType: params.triggerType,
            content: orderParams,
            createTime: block.timestamp,
            deadline: params.deadline
        });

        isConditional = true;
        conditionalOrders.push(order);
        orderId = conditionalOrders.length;
        takerConditionalOrders[params.taker][params.marketId].push(orderId);

        emit CreatedTpSl(params.marketId, params.taker, increaseParams.direction, params.triggerType, params.amount, orderId, params.executionFee, params.deadline, params.tp, params.sl);
    }

    function addMargin(bytes32 marketId, bool direction, uint256 amount) payable external nonReentrant {
        address marginToken = IMarkets(markets).getMarketConfig(marketId).margin;
        if (marginToken == wETH && msg.value == amount) {
            IWETH(wETH).deposit{value: amount}();
        }
        else {
            SafeERC20.safeTransferFrom(IERC20(marginToken), msg.sender, address(this), amount);
        }
        SafeERC20.forceApprove(IERC20(marginToken), markets, amount);

        IMarkets(markets).addMargin(marketId, msg.sender, direction, toInt256(amount));
    }

    function createOrder(int8 orderType, int8 triggerType, bytes32 marketId, uint256 deadline, uint256 executionPrice, OrderParams memory content) private returns(uint256 orderId, bool isConditional) {
        Order memory order = Order({
            orderType: orderType,
            triggerType: triggerType,
            status: 0,
            content: content,
            createTime: block.timestamp,
            deadline: deadline
        });


        isConditional = executionPrice > 0;
        if (isConditional) {
            conditionalOrders.push(order);
            orderId = conditionalOrders.length;
            takerConditionalOrders[msg.sender][marketId].push(orderId);
        } else {
            orders.push(order);
            orderId = orders.length;
            takerOrders[msg.sender][marketId].push(orderId);
        }
    }

    function updateTpSl(uint256 orderId, uint256 tp, uint256 sl, uint256 deadline) public override nonReentrant {
        require(deadline >= block.timestamp + 300, InvalidDeadline());
        Order memory order = conditionalOrders[orderId-1];
        require(order.status == 0, InvalidStatus(order.status));
        require(msg.sender == order.content.increaseParams.taker, InvalidOrder());
        if (order.content.increaseParams.direction) {
            if (tp == 0) tp = 1e28;
            require(tp > sl, InvalidTpSl(tp, sl));
        }
        else {
            if (sl == 0) sl = 1e28;
            require(sl > tp, InvalidTpSl(tp, sl));
        }

        order.content.tp = tp;
        order.content.sl = sl;
        order.deadline = deadline;

        conditionalOrders[orderId-1] = order;

        emit UpdatedTpSl(order.content.increaseParams.taker, orderId, tp, sl, deadline);
    }

    function cancelOrder(uint256 orderId, bool isConditional) public override nonReentrant {
        orderId -= 1;
        Order memory order = isConditional ? conditionalOrders[orderId] : orders[orderId];
        require(order.status == 0, InvalidStatus(order.status));
        if (block.timestamp < order.deadline) {
            require(order.content.increaseParams.taker == msg.sender, NotCancel(0));
            require(block.timestamp > order.createTime + 300, NotCancel(order.createTime + 300));
        }

        uint256 margin = uint256(order.content.increaseParams.margin);
        if (order.orderType == 1) {
            address assetToken = IPools(pools).getPoolConfig(order.content.increaseParams.marketId).asset;
            if (assetToken == wETH) {
                IWETH(wETH).withdraw(margin);
                sendEth(order.content.increaseParams.taker, false, order.content.executionFee+order.content.tpSlExecutionFee+margin);
            }
            else {
                sendEth(order.content.increaseParams.taker, false, order.content.executionFee+order.content.tpSlExecutionFee);
                SafeERC20.safeTransfer(IERC20(assetToken), order.content.increaseParams.taker, margin);    
            }
        } 
        else {
            sendEth(order.content.increaseParams.taker, false, order.content.executionFee+order.content.tpSlExecutionFee);
        }


        removeUserOrder(orderId+1, order.content.increaseParams.marketId, order.content.increaseParams.taker, isConditional);
        if (isConditional) {
            conditionalOrders[orderId].status = 2;
        }
        else {
            orders[orderId].status = 2;
        }


        orderId += 1;
        emit CanceledOrder(order.content.increaseParams.taker, orderId, isConditional);
    }

    function removeUserOrder(uint256 orderId, bytes32 marketId, address taker, bool isConditional) private {
        if (isConditional) {
            uint256 len = takerConditionalOrders[taker][marketId].length;
            for (uint256 i = 0; i < len; i++) {
                if (takerConditionalOrders[taker][marketId][i] == orderId) {
                    takerConditionalOrders[taker][marketId][i] = takerConditionalOrders[taker][marketId][len-1];
                    takerConditionalOrders[taker][marketId].pop();
                    break;
                }
            }
        } else {
            uint256 len = takerOrders[taker][marketId].length;
            for (uint256 i = 0; i < len; i++) {
                if (takerOrders[taker][marketId][i] == orderId) {
                    takerOrders[taker][marketId][i] = takerOrders[taker][marketId][len-1];
                    takerOrders[taker][marketId].pop();
                    break;
                }
            }
        }
    }

    function updatePriceAndLiquidatePosition(bytes32 marketId, address taker, bool direction, bytes32[] memory priceIds, bytes[] memory priceUpdateData) public payable override nonReentrant returns(int256 marginBalance, int256 tradeAmount, int256 tradeValue) {
        IPriceHelper(priceHelper).updatePrice{value: msg.value}(priceIds, priceUpdateData);
        (marginBalance, tradeAmount, tradeValue) = IMarkets(markets).liquidate(marketId, taker, msg.sender, direction);
        if (marginBalance > 0) {
            uint256 margin = uint256(marginBalance);
            address assetToken = IPools(pools).getPoolConfig(marketId).asset;
            if (assetToken == wETH) {
                sendEth(taker, true, margin);
            } else {
                SafeERC20.safeTransfer(IERC20(assetToken), taker, margin);
            }
        }
    }

    struct ExecVars {
        uint256 currentGas;
        uint256 price;
        uint256 useGas;
        uint256 maxGas;
    }
    /**
     * @notice execute order
     * @return result 1 success, 2 fail, 3 error status, 4 deadline, 5 not execute, 6 not trigger
     */
    function execOrder(uint256 orderId, bool isConditional) private nonReentrant returns(uint8 result) {
        ExecVars memory vars;
        vars.currentGas = gasleft();

        Order memory order = isConditional ? conditionalOrders[orderId] : orders[orderId];
        if (order.status != 0) return 3;
        IMarkets.IncreasePositionParams memory increaseParams = order.content.increaseParams;
        IMarkets.MarketConfig memory config = IMarkets(markets).getMarketConfig(increaseParams.marketId);

        vars.price = uint256(IPriceHelper(priceHelper).getIndexPrice(config.pairId));
        if (order.triggerType > 0) {
            vars.price = uint256(IPools(pools).getMarketPrice(increaseParams.marketId, int256(vars.price)));
        } 

        if (order.deadline < block.timestamp)  return 4;
        if (block.timestamp <= order.createTime || increaseParams.taker == msg.sender) return 5;

        if (order.orderType == 1) {
            if (order.content.executionPrice > 0) {
                if (increaseParams.direction == (vars.price > order.content.executionPrice)) return 6;
            }

            SafeERC20.forceApprove(IERC20(config.margin), markets, uint256(increaseParams.margin));
            try IMarkets(markets).increasePosition(increaseParams) {
                result = 1;
                order.status = 1;
                if (order.content.tp > 0 || order.content.sl > 0) {
                    _createTpSl(TpSlParams({
                        marketId: increaseParams.marketId,
                        taker: increaseParams.taker,
                        direction: increaseParams.direction,
                        amount: uint256(increaseParams.amount),
                        triggerType: order.triggerType,
                        tp: order.content.tp,
                        sl: order.content.sl,
                        executionFee: order.content.tpSlExecutionFee,
                        deadline: block.timestamp + 30 days
                    }));
                }
            } catch {
                result = 2;
                order.status = -1;
            }
        }
        else {
            if (order.orderType == 2) {
                if (order.content.executionPrice > 0)
                    if (increaseParams.direction == (vars.price < order.content.executionPrice)) return 6;
            }
            else {
                if (increaseParams.direction ?
                    (vars.price < order.content.tp && vars.price > order.content.sl) :
                    (vars.price > order.content.tp && vars.price < order.content.sl)
                ) return 6;
            }

            try IMarkets(markets).decreasePosition(increaseParams.marketId, increaseParams.taker, increaseParams.direction, increaseParams.amount) returns(int256 marginBalance, int256, int256) {
                result = 1;
                order.status = 1;
                if (marginBalance > 0) {
                    uint256 margin = uint256(marginBalance);
                    if (config.margin == wETH) {
                        sendEth(increaseParams.taker, true, margin);
                    } else {
                        SafeERC20.safeTransfer(IERC20(config.margin), increaseParams.taker, margin);
                    }
                }
            }
            catch {
                result = 2;
                order.status = -1;
            }
        }


        isConditional ? conditionalOrders[orderId] = order : orders[orderId] = order;

        removeUserOrder(orderId+1, increaseParams.marketId, increaseParams.taker, isConditional);

        vars.useGas = vars.currentGas - gasleft();
        vars.maxGas = vars.useGas * tx.gasprice * 2;

        if (order.content.executionFee <= vars.maxGas) {
            sendEth(msg.sender, false, order.content.executionFee);
        } else {
            sendEth(msg.sender, false, vars.maxGas);
            sendEth(increaseParams.taker, false, order.content.executionFee-vars.maxGas);
        }

        emit ExecutedOrder(increaseParams.marketId, msg.sender, increaseParams.taker, isConditional, orderId+1, order.orderType, order.content.executionFee, order.triggerType, order.status, vars.price);
    }

    function executeOrder(uint256 executeNum) public override returns(uint8[] memory results) {
        if (executeNum > 5) executeNum = 5;
        uint256 len = orders.length;
        uint256 eop = executedOrderPosition;
        if (len > eop) {
            uint256 diff = len - eop;
            uint256 oid;
            bool update = true;
            if (executeNum > diff) executeNum = diff;

            results = new uint8[](executeNum);
            for (uint256 i = 0; i < executeNum; i++) {
                oid = eop+i;

                results[i] = execOrder(oid, false);
                if (results[i] < 5 && update) executedOrderPosition = oid+1;
                else update = false;
            }
        }
    }

    function executeConditionalOrder(uint256[] memory orderIds) public override returns(uint8[] memory results) {
        uint256 len = orderIds.length;
        require(len < 6, TooMany());
        
        results = new uint8[](len);
        for (uint256 i = 0; i < len; i++) {
            results[i] = execOrder(orderIds[i]-1, true);
        }
    }

    function updatePriceAndExecuteOrder(uint256 executeNum, bytes32[] memory priceIds, bytes[] memory priceUpdateData) payable external override returns(uint8[] memory results) {
        IPriceHelper(priceHelper).updatePrice{value: msg.value}(priceIds, priceUpdateData);
        results = executeOrder(executeNum);
    }

    function updatePriceAndExecuteConditionalOrder(uint256[] memory ids, bytes32[] memory priceIds, bytes[] memory priceUpdateData) payable external override returns(uint8[] memory results) {
        IPriceHelper(priceHelper).updatePrice{value: msg.value}(priceIds, priceUpdateData);

        results = executeConditionalOrder(ids);
    }

    function toInt256(uint256 value) internal pure returns (int256) {
        if (value > uint256(type(int256).max)) {
            revert BigNumber();
        }
        return int256(value);
    }

    // prevent reentrancy
    function sendEth(address to, bool warped, uint256 amount) private {
        if (to.code.length == 0) {
            if (warped) IWETH(wETH).withdraw(amount);
            (bool success, ) = payable(to).call{value: amount}(new bytes(0));
            require(success, SendFail());
        }
        else {
            if (!warped) IWETH(wETH).deposit{value: amount}();
            SafeERC20.safeTransfer(IERC20(wETH), to, amount);
        }
    }
}