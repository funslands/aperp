// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./interfaces/IPoolPlugin.sol";
import "../core/interfaces/IPriceHelper.sol";
import "./interfaces/IWETH.sol";
import "../libraries/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract PoolPlugin is IPoolPlugin, ReentrancyGuard {
    address immutable wETH;
    address public immutable pools;
    address public immutable priceHelper;
    uint256 public immutable minimumExecutionFee;
    
    uint256 public override executedOrderPosition;
    Order[] private orders;
    Order[] private conditionalOrders;

    // maker => poolId => orderId
    mapping(address=> mapping(bytes32=>uint256[])) private makerOrders;
    mapping(address=> mapping(bytes32=>uint256[])) private makerConditionalOrders;

    receive() external payable { }

    constructor(address _wETH, address _pools, address _priceHelper, uint256 _minimumExecutionFee) {
        require(_minimumExecutionFee >= 0.000001 ether && _minimumExecutionFee <= 0.01 ether, InvalidMiniExecutionFee());
        wETH = _wETH;
        pools = _pools;
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

    function getMakerOrders(address maker, bytes32 poolId) external view returns(uint256[] memory) {
        return makerOrders[maker][poolId];
    }
    function getMakerConditionalOrders(address maker, bytes32 poolId) external view returns(uint256[] memory) {
        return makerConditionalOrders[maker][poolId];
    }

    function createAddOrder(OrderParams memory params, uint256 deadline) payable external override nonReentrant returns(uint256 orderId, bool isConditional) {
        require(deadline >= block.timestamp + 300, InvalidDeadline());
        require(params.executionFee >= minimumExecutionFee, InvalidExecutionFee(params.executionFee));
        if (params.tp > 0 || params.sl > 0) {
            if (params.tp == 0) params.tp = 1e28;
            require(params.tp > params.sl, IPoolPlugin.InvalidTpSl(params.tp, params.sl));
            require(params.tpSlExecutionFee >= minimumExecutionFee, InvalidExecutionFee(params.tpSlExecutionFee));
        }
        else {
            params.tpSlExecutionFee = 0;
        }

        uint256 execFee = params.executionFee + params.tpSlExecutionFee;

        IPools.PoolConfig memory poolConfig = IPools(pools).getPoolConfig(params.poolId);

        require(toInt256(params.amount) >= poolConfig.dust, InvalidAmount());
        require(toInt256(params.margin) >= poolConfig.minimumMargin, InvalidMargin());

        // transfer asset
        address assetToken = poolConfig.asset;
        if (assetToken == wETH && msg.value > execFee) {
            require(msg.value == execFee + params.margin, InsufficientFee());
            IWETH(wETH).deposit{value: params.margin}();
        } else {
            require(msg.value == execFee, InsufficientFee());
            SafeERC20.safeTransferFrom(IERC20(assetToken), msg.sender, address(this), params.margin);
        }

        if (params.maker != msg.sender) params.maker = msg.sender;

        (orderId, isConditional) = createOrder(1, params.poolId, deadline, params.executionPrice, params);

        emit CreatedAddOrder(params.poolId, params.maker, isConditional, orderId, params.executionFee, params.executionPrice, deadline, params.margin, params.amount);
    }

    function createRemoveOrder(OrderParams memory params, uint256 deadline) payable external override nonReentrant returns(uint256 orderId, bool isConditional) {
        require(deadline >= block.timestamp + 300, InvalidDeadline());
        require(params.amount > 0, InvalidAmount());

        require(params.executionFee >= minimumExecutionFee, InvalidExecutionFee(params.executionFee));
        require(msg.value == params.executionFee, InsufficientFee());

        IPools.Position memory position = IPools(pools).getPosition(params.poolId, msg.sender);
        require(position.amount > 0, NotPosition());

        if (params.maker != msg.sender) params.maker = msg.sender;

        (orderId, isConditional) = createOrder(2, params.poolId, deadline, params.executionPrice, params);

        emit CreatedRemoveOrder(params.poolId, params.maker, isConditional, orderId, msg.value, params.executionPrice, deadline, params.amount);
    }

    function createTpSl(TpSlParams memory params) payable public override nonReentrant returns(uint256 orderId, bool isConditional) {
        require(params.executionFee >= minimumExecutionFee, InvalidExecutionFee(params.executionFee));
        require(msg.value == params.executionFee, InsufficientFee());
        if (params.maker != msg.sender) params.maker = msg.sender;
        (orderId, isConditional) = _createTpSl(params);
    }
    function _createTpSl(TpSlParams memory params) private returns(uint256 orderId, bool isConditional) {
        require(params.tp > 0 || params.sl > 0, InvalidTpSl(params.tp, params.sl));
        if (params.tp == 0) params.tp = 1e28;
        require(params.tp > params.sl, InvalidTpSl(params.tp, params.sl));

        IPools.Position memory position = IPools(pools).getPosition(params.poolId, params.maker);
        require(position.amount > 0, NotPosition());


        OrderParams memory orderInfo = OrderParams({
            poolId: params.poolId,
            maker: params.maker,
            amount: params.amount,
            margin: 0,
            tp: params.tp,
            sl: params.sl,
            executionPrice: 0,
            executionFee: params.executionFee,
            tpSlExecutionFee: 0
        });

        Order memory order = Order({
            orderType: 3,
            status: 0,
            content: orderInfo,
            createTime: block.timestamp,
            deadline: params.deadline
        });

        isConditional = true;
        conditionalOrders.push(order);
        orderId = conditionalOrders.length;
        makerConditionalOrders[params.maker][params.poolId].push(orderId);

        emit CreatedTpSl(params.poolId, params.maker, params.amount, orderId, params.executionFee, params.deadline, params.tp, params.sl);
    }

    function addMargin(bytes32 poolId, uint256 amount) payable public override nonReentrant {
        address assetToken = IPools(pools).getPoolConfig(poolId).asset;
        if (assetToken == wETH && msg.value == amount) {
            IWETH(wETH).deposit{value: amount}();
        }
        else {
            SafeERC20.safeTransferFrom(IERC20(assetToken), msg.sender, address(this), amount);
        }
        SafeERC20.forceApprove(IERC20(assetToken), pools, amount);

        IPools(pools).addMargin(poolId, msg.sender, toInt256(amount));
    }

    function createOrder(int8 orderType, bytes32 poolId, uint256 deadline, uint256 executionPrice, OrderParams memory content) private returns(uint256 orderId, bool isConditional) {
        Order memory order = Order({
            orderType: orderType,
            status: 0,
            content: content,
            createTime: block.timestamp,
            deadline: deadline
        });

        
        isConditional = executionPrice > 0;
        if (isConditional) {
            conditionalOrders.push(order);
            orderId = conditionalOrders.length;
            makerConditionalOrders[msg.sender][poolId].push(orderId);
        } else {
            orders.push(order);
            orderId = orders.length;
            makerOrders[msg.sender][poolId].push(orderId);
        }
    }

    function updateTpSl(uint256 orderId, uint256 tp, uint256 sl, uint256 deadline) public override nonReentrant {
        require(tp > 0 || sl > 0, InvalidTpSl(tp, sl));
        if (tp == 0) tp = 1e28;
        require(tp > sl, InvalidTpSl(tp, sl));

        Order memory order = conditionalOrders[orderId-1];
        require(order.status == 0, InvalidStatus(order.status));

        require(msg.sender == order.content.maker, InvalidOrder());

        order.content.tp = tp;
        order.content.sl = sl;
        order.deadline = deadline;

        conditionalOrders[orderId-1] = order;

        emit UpdatedTpSl(order.content.maker, orderId, tp, sl, deadline);
    }

    function cancelOrder(uint256 orderId, bool isConditional) public override nonReentrant {
        orderId -= 1;
        Order memory order = isConditional ? conditionalOrders[orderId] : orders[orderId];
        require(order.status == 0, InvalidStatus(order.status));
        if (block.timestamp < order.deadline) {
            require(order.content.maker == msg.sender, NotCancel(0));
            require(block.timestamp > order.createTime + 300, NotCancel(order.createTime + 300));
        }
        

        if (order.orderType == 1) {
            address assetToken = IPools(pools).getPoolConfig(order.content.poolId).asset;
            if (assetToken == wETH) {
                IWETH(wETH).withdraw(order.content.margin);
                sendEth(order.content.maker, false, order.content.executionFee+order.content.tpSlExecutionFee+order.content.margin);
            }
            else {
                sendEth(order.content.maker, false, order.content.executionFee+order.content.tpSlExecutionFee);
                SafeERC20.safeTransfer(IERC20(assetToken), order.content.maker, order.content.margin);    
            }
        } 
        else {
            sendEth(order.content.maker, false, order.content.executionFee+order.content.tpSlExecutionFee);
        }


        removeUserOrder(orderId+1, order.content.poolId, order.content.maker, isConditional);
        if (isConditional) {
            conditionalOrders[orderId].status = 2;
        }
        else {
            orders[orderId].status = 2;
        }

        
        orderId += 1;
        emit CanceledOrder(order.content.maker, orderId, isConditional);
    }

    function removeUserOrder(uint256 orderId, bytes32 poolId, address maker, bool isConditional) private {
        if (isConditional) {
            uint256 len = makerConditionalOrders[maker][poolId].length;
            for (uint256 i = 0; i < len; i++) {
                if (makerConditionalOrders[maker][poolId][i] == orderId) {
                    makerConditionalOrders[maker][poolId][i] = makerConditionalOrders[maker][poolId][len-1];
                    makerConditionalOrders[maker][poolId].pop();
                    break;
                }
            }
        } else {
            uint256 len = makerOrders[maker][poolId].length;
            for (uint256 i = 0; i < len; i++) {
                if (makerOrders[maker][poolId][i] == orderId) {
                    makerOrders[maker][poolId][i] = makerOrders[maker][poolId][len-1];
                    makerOrders[maker][poolId].pop();
                    break;
                }
            }
        }
    }

    function updatePriceAndLiquidateLiquidity(bytes32 poolId, address maker, bytes32[] memory priceIds, bytes[] memory priceUpdateData) public payable nonReentrant override returns(int256 marginBalance, int256 liquidateAmount) {
        IPriceHelper(priceHelper).updatePrice{value: msg.value}(priceIds, priceUpdateData);
        (marginBalance, liquidateAmount) = IPools(pools).liquidate(poolId, maker, msg.sender);
        if (marginBalance > 0) {
            uint256 margin = uint256(marginBalance);
            address assetToken = IPools(pools).getPoolConfig(poolId).asset;
            if (assetToken == wETH) {
                sendEth(maker, true, margin);
            } else {
                SafeERC20.safeTransfer(IERC20(assetToken), maker, margin);
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

        vars.price = uint256(IPools(pools).getNetValue(order.content.poolId)); 
        if (order.deadline < block.timestamp)  return 4;
        if (block.timestamp <= order.createTime || order.content.maker == msg.sender) return 5;

        if (order.orderType == 1) {
            if (order.content.executionPrice > 0) {
                if (vars.price > order.content.executionPrice) return 6;
            }

            address assetToken = IPools(pools).getPoolConfig(order.content.poolId).asset;
            SafeERC20.forceApprove(IERC20(assetToken), pools, uint256(order.content.margin));
            try IPools(pools).addLiquidity(order.content.poolId, order.content.maker, toInt256(order.content.margin), toInt256(order.content.amount)) {
                result = 1;
                order.status = 1;
                if (order.content.tp > 0 || order.content.sl > 0) {
                    _createTpSl(TpSlParams({
                        poolId: order.content.poolId,
                        maker: order.content.maker,
                        amount: order.content.amount,
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
                    if (vars.price < order.content.executionPrice) return 6;
            }
            else {
                if (order.content.tp > 0 || order.content.sl > 0)
                    if (vars.price < order.content.tp && vars.price > order.content.sl) return 6;
            }

            try IPools(pools).removeLiquidity(order.content.poolId, order.content.maker, toInt256(order.content.amount), address(this)) returns(int256 marginBalance, int256) {
                result = 1;
                order.status = 1;
                if (marginBalance > 0) {
                    uint256 margin = uint256(marginBalance);
                    address assetToken = IPools(pools).getPoolConfig(order.content.poolId).asset;
                    if (assetToken == wETH) {
                        sendEth(order.content.maker, true, margin);
                    } else {
                        SafeERC20.safeTransfer(IERC20(assetToken), order.content.maker, margin);
                }
            }
            } catch {
                result = 2;
                order.status = -1;
            }
        }

        isConditional ? conditionalOrders[orderId] = order : orders[orderId] = order;
        removeUserOrder(orderId+1, order.content.poolId, order.content.maker, isConditional);
        vars.useGas = vars.currentGas - gasleft();
        vars.maxGas = vars.useGas * tx.gasprice * 2;

        if (order.content.executionFee <= vars.maxGas) {
            sendEth(msg.sender, false, order.content.executionFee);
        } else {
            sendEth(msg.sender, false, vars.maxGas);
            sendEth(order.content.maker, false, order.content.executionFee - vars.maxGas);
        }

        emit ExecutedOrder(order.content.poolId, msg.sender, order.content.maker, isConditional, orderId+1, order.orderType, order.content.executionFee, vars.price);
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