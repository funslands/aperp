// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./Init.sol";
import "../src/test/Trader.sol";
import "../src/plugin/PoolPlugin.sol";
import "../src/plugin/TakerPlugin.sol";

contract TakerPluginTest is Init {
    PoolPlugin public pp;
    TakerPlugin public tp;
    address public t0 = vm.addr(0xadd00ff001);
    Trader public t1;
    Trader public t2;
    Trader public t3;
    Trader public t4;

    function setUp() public {
        initial();

        pp = new PoolPlugin(address(eth), address(pools), address(ph), 1e14);
        tp = new TakerPlugin(address(eth), address(pools), address(markets), address(ph), 0.0001 ether);
        pools.addPlugin(address(pp));
        markets.addPlugin(address(tp));

        t1 = new Trader();
        t2 = new Trader();
        t3 = new Trader();
        t4 = new Trader();

        vm.label(t0, "T0");
        vm.label(address(t1), "T1");
        vm.label(address(t2), "T2");
        vm.label(address(t3), "T3");
        vm.label(address(t4), "T4");

        vm.deal(address(t0), 100 ether);
        vm.deal(address(t1), 100 ether);
        vm.deal(address(t2), 100 ether);
        vm.deal(address(t3), 100 ether);
        vm.deal(address(t4), 100 ether);

        usd.mint(address(t0), 10000e6);
        usd.mint(address(t1), 10000e6);
        usd.mint(address(t2), 10000e6);
        usd.mint(address(t3), 10000e6);
        usd.mint(address(t4), 10000e6);

        vm.startPrank(t0);
        usd.approve(address(pp), 1e20);
        eth.approve(address(pp), 1e20);
        usd.approve(address(tp), 1e20);
        eth.approve(address(tp), 1e20);
        eth.deposit{value: 50e18}();
        vm.stopPrank();

        t1.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t2.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t3.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t4.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));

        t1.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(tp), 1e20));
        t2.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(tp), 1e20));
        t3.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(tp), 1e20));
        t4.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(tp), 1e20));

        t1.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t2.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t3.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t4.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));

        t1.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(tp), 1e20));
        t2.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(tp), 1e20));
        t3.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(tp), 1e20));
        t4.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(tp), 1e20));

        t1.dos(address(eth), 50e18, abi.encodeWithSelector(eth.deposit.selector));
        t2.dos(address(eth), 50e18, abi.encodeWithSelector(eth.deposit.selector));
        t3.dos(address(eth), 50e18, abi.encodeWithSelector(eth.deposit.selector));
        t4.dos(address(eth), 50e18, abi.encodeWithSelector(eth.deposit.selector));

        t1.dos(address(pools), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(pp), true));
        t2.dos(address(pools), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(pp), true));
        t3.dos(address(pools), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(pp), true));
        t4.dos(address(pools), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(pp), true));

        t1.dos(address(markets), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(tp), true));
        t2.dos(address(markets), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(tp), true));
        t3.dos(address(markets), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(tp), true));
        t4.dos(address(markets), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(tp), true));

        pools.approve(address(this), true);
        markets.addPlugin(address(this));

        vm.startPrank(address(t0));
        pools.approve(address(this), true);
        markets.approve(address(this), true);
        vm.stopPrank();
        vm.startPrank(address(t1));
        pools.approve(address(this), true);
        markets.approve(address(this), true);
        markets.approve(address(t1), true);
        vm.stopPrank();
        vm.startPrank(address(t2));
        pools.approve(address(this), true);
        vm.stopPrank();
        vm.startPrank(address(a2));
        pools.approve(address(this), true);
        markets.approve(address(this), true);
        markets.approve(address(a2), true);
        vm.stopPrank();
    }

    function testParams() public { 
        vm.warp(1740800000);
        IMarkets.IncreasePositionParams memory p = IMarkets.IncreasePositionParams({
            marketId: ethPoolId,
            taker: t0,
            direction: true,
            margin: 1e18,
            amount: 5e20
        });
        ITakerPlugin.OrderParams memory params = ITakerPlugin.OrderParams({
            increaseParams: p,
            tp: 0,
            sl: 0,
            executionPrice: 2000e8,
            executionFee: 2e14,
            tpSlExecutionFee: 1e14
        });

        vm.expectRevert(ITakerPlugin.InvalidDeadline.selector);
        tp.createIncreaseOrder(params, 1740800200, 0);

        params.executionFee = 0.00001 ether;
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidExecutionFee.selector, 0.00001 ether));
        tp.createIncreaseOrder(params, 1740800400, 0);

        params.executionFee = 0.0001 ether;
        params.executionPrice = 1990e8;
        params.sl = 1980e8;
        params.tpSlExecutionFee = 0.00002 ether;
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidExecutionFee.selector, 0.00002 ether));
        tp.createIncreaseOrder(params, 1740800400, 0);

        params.increaseParams.amount = 1e16-1;
        params.sl = 1980e8;
        params.tpSlExecutionFee = 0.0002 ether;
        vm.expectRevert(ITakerPlugin.InvalidAmount.selector);
        tp.createIncreaseOrder(params, 1740800400, 0);

        params.increaseParams.amount = 15e20;
        params.increaseParams.margin = 1e16-1;
        vm.expectRevert(ITakerPlugin.InvalidMargin.selector);
        tp.createIncreaseOrder(params, 1740800400, 0);

        params.increaseParams.direction = true;
        params.tp = 2100e10;
        params.sl = 2120e10;
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidTpSl.selector, params.tp, params.sl));
        tp.createIncreaseOrder(params, 1740800400, 0);

        params.increaseParams.direction = false;
        params.tp = 960e10;
        params.sl = 930e10;
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidTpSl.selector, params.tp, params.sl));
        tp.createIncreaseOrder(params, 1740800400, 0);


        params.executionPrice = 0;
        params.executionFee = 1e14;
        params.tp = 0;
        params.sl = 0;
        params.tpSlExecutionFee = 1e14;
        vm.expectRevert(ITakerPlugin.InsufficientFee.selector);
        vm.startPrank(address(t1));
        tp.createDecreaseOrder{value: 1e13}(params, 1740800400, 0);
        vm.stopPrank();

        params.sl = 1950e8;
        vm.expectRevert(ITakerPlugin.InsufficientFee.selector);
        vm.startPrank(address(t1));
        tp.createDecreaseOrder{value: 11e13}(params, 1740800400, 0);
        vm.stopPrank();

        vm.expectRevert(ITakerPlugin.InsufficientFee.selector);
        vm.startPrank(address(t1));
        tp.createDecreaseOrder{value: 20002e14}(params, 1740800400, 0);
        vm.stopPrank();

        vm.expectRevert(ITakerPlugin.InvalidDeadline.selector);
        tp.createDecreaseOrder(params, 1740800200, 0);

        params.increaseParams.amount = 0;
        vm.expectRevert(ITakerPlugin.InvalidAmount.selector);
        tp.createDecreaseOrder(params, 1740800400, 0);

        params.increaseParams.amount = 15e18;
        params.executionFee = 0.0002 ether;
        vm.expectRevert(ITakerPlugin.InsufficientFee.selector);
        tp.createDecreaseOrder(params, 1740800400, 0);

        vm.expectRevert(ITakerPlugin.NotPosition.selector);
        vm.startPrank(address(t1));
        tp.createDecreaseOrder{value: 0.0002 ether}(params, 1740800800, 1);
        vm.stopPrank();

        ITakerPlugin.TpSlParams memory tsp = ITakerPlugin.TpSlParams({
            marketId: ethPoolId,
            taker: t0,
            direction: false,
            amount: 5e20,
            triggerType: 0,
            tp: 0,
            sl: 0,
            deadline: 1740802000,
            executionFee: 1e14
        });

        tsp.executionFee = 0.00005 ether;
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidExecutionFee.selector, 0.00005 ether));
        tp.createTpSl(tsp);

        tsp.executionFee = 0.0002 ether;
        vm.expectRevert(ITakerPlugin.InsufficientFee.selector);
        tp.createTpSl(tsp);

        vm.expectRevert(ITakerPlugin.InsufficientFee.selector);
        tp.createTpSl{value: 0.0001 ether}(tsp);

        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidTpSl.selector, 0, 0));
        tp.createTpSl{value: 0.0002 ether}(tsp);

        tsp.tp = 2100e8;
        vm.expectRevert(ITakerPlugin.NotPosition.selector);
        tp.createTpSl{value: 0.0002 ether}(tsp);

        tsp.direction = true;
        tsp.tp = 2100e10;
        tsp.sl = 2120e10;
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidTpSl.selector, tsp.tp, tsp.sl));
        tp.createTpSl{value:0.0002 ether}(tsp);

        tsp.direction = false;
        tsp.tp = 960e10;
        tsp.sl = 930e10;
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidTpSl.selector, tsp.tp, tsp.sl));
        tp.createTpSl{value:0.0002 ether}(tsp);

        setPrice(ethId, 2000e8);
        p.taker = address(t1);
        p.amount = 5e20;
        p.margin = 1e18;
        p.direction = false;
        tsp.tp = 960e10;
        tsp.sl = 1030e10;
        vm.startPrank(address(t1));
        eth.approve(address(markets), 1e20);
        markets.increasePosition(p);
        tp.createTpSl{value: 2e14}(tsp);
        vm.stopPrank();
    }

    function testOrder() public {
        vm.warp(1740800000);
        setPrice(ethId, 2000e8);
        uint256 oid;
        bool isConditional;
        uint8[] memory results;
        IMarkets.IncreasePositionParams memory p = IMarkets.IncreasePositionParams({
            marketId: ethPoolId,
            taker: t0,
            direction: true,
            margin: 1e18,
            amount: 5e20
        });
        ITakerPlugin.OrderParams memory params = ITakerPlugin.OrderParams({
            increaseParams: p,
            tp: 0,
            sl: 0,
            executionPrice: 0,
            executionFee: 2e14,
            tpSlExecutionFee: 1e14
        });

        // t1 create eth long order
        {
            params.sl = 1966e10;
            vm.startPrank(address(t1));
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedIncreaseOrder(ethPoolId, address(t1), true, false, 0, 1, 2e14, 0, 1740800500, 1e18, 5e20);
            (oid, isConditional) = tp.createIncreaseOrder{value: 3e14}(params, 1740800500, 0);
            vm.stopPrank();
            vm.assertEq(oid, 1);
            vm.assertEq(isConditional, false);
            assertTakerOrder(oid, isConditional, 0, 1, 0, address(t1));
            assertTakerOrders(ethPoolId, false, address(t1), 1);
            vm.assertEq(address(t1).balance, 50e18-3e14);
            vm.assertEq(eth.balanceOf(address(t1)), 49e18);
        }

        // t2 create eth short order
        {
            params.increaseParams.direction = false;
            params.increaseParams.amount = 7e20;
            params.increaseParams.margin = 15e17;
            params.tp = 0;
            params.sl = 0;
            params.tpSlExecutionFee = 1e14;
            vm.startPrank(address(t2));
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedIncreaseOrder(ethPoolId, address(t2), false, false, 0, 2, 2e14, 0, 1740800800, 15e17, 7e20);
            (oid, isConditional) = tp.createIncreaseOrder{value: 15002e14}(params, 1740800800, 0);
            vm.stopPrank();
            vm.assertEq(oid, 2);
            vm.assertEq(isConditional, false);
            assertTakerOrder(oid, isConditional, 0, 1, 0, address(t2));
            assertTakerOrders(ethPoolId, false, address(t2), 1);
            vm.assertEq(address(t2).balance, 50e18-15002e14);
            vm.assertEq(eth.balanceOf(address(t2)), 50e18);
        }

        // t3 create usd short order
        {
            params.increaseParams.marketId = usdPoolId;
            params.increaseParams.amount = 1e19;
            params.increaseParams.margin = 1000e6;
            params.tp = 83000e10;
            params.sl = 0;
            params.tpSlExecutionFee = 1e14;
            vm.startPrank(address(t3));
            usd.approve(address(tp), 1e18);
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedIncreaseOrder(usdPoolId, address(t3), false, false, 0, 3, 2e14, 0, 1740800460, 1000e6, 1e19);
            (oid, isConditional) = tp.createIncreaseOrder{value: 3e14}(params, 1740800460, 0);
            vm.stopPrank();
            vm.assertEq(oid, 3);
            vm.assertEq(isConditional, false);
            assertTakerOrder(oid, isConditional, 0, 1, 0, address(t3));
            assertTakerOrders(usdPoolId, false, address(t3), 1);
            vm.assertEq(address(t3).balance, 50e18-3e14);
            vm.assertEq(usd.balanceOf(address(t3)), 9000e6);
        }

        // t4 create usd long order 8
        {
            params.increaseParams.amount = 4e18;
            params.increaseParams.margin = 500e6;
            params.tp = 66000e10;
            params.sl = 78000e10;
            params.tpSlExecutionFee = 1e14;
            vm.startPrank(address(t4));
            usd.approve(address(tp), 1e18);
            for (uint256 i=0; i<8; i++) {
                params.tp += 10e10;
                params.sl -= 15e10;
                tp.createIncreaseOrder{value: 3e14}(params, 1740800900+i*10, 0);
            }
            vm.stopPrank();
            assertTakerOrders(usdPoolId, false, address(t4), 8);
            vm.assertEq(address(t4).balance, 50e18-3e14*8);
            vm.assertEq(usd.balanceOf(address(t4)), 6000e6);
        }

        assertTakerOrders(ethPoolId, true, address(t1), 0);
        assertTakerOrders(ethPoolId, true, address(t2), 0);
        assertTakerOrders(usdPoolId, true, address(t3), 0);
        assertTakerOrders(usdPoolId, true, address(t4), 0);

        // execute order
        vm.txGasPrice(10);
        results = tp.executeOrder(1);
        vm.assertEq(results.length, 1);
        vm.assertEq(results[0], 5);

        vm.warp(block.timestamp + 1);
        vm.expectEmit(address(tp));
        emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), false, 1, 1, 2e14, 0, 1, 2000e10);
        emit ITakerPlugin.CreatedTpSl(ethPoolId, address(t1), true, 0, 5e20, 1, 1e14, 1740800001+30 days, 1e28, 1966e10);
        results = tp.executeOrder(1);
        vm.assertEq(results.length, 1);
        vm.assertEq(results[0], 1);
        assertTakerOrder(1, false, 1, 1, 0, address(t1));
        assertTakerOrder(1, true, 0, 3, 0, address(t1));
        vm.assertEq(tp.executedOrderPosition(), 1);
        assertTakerOrders(ethPoolId, false, address(t1), 0);
        assertTakerOrders(ethPoolId, false, address(t2), 1);
        assertTakerOrders(usdPoolId, false, address(t3), 1);
        assertTakerOrders(usdPoolId, false, address(t4), 8);

        vm.startPrank(address(t0));
        results = updatePriceAndExecuteOrder(3, 80000e8, 2000e8, true);
        vm.stopPrank();
        vm.assertEq(tp.executedOrderPosition(), 4);
        vm.assertEq(results.length, 3);
        vm.assertEq(results[0], 1);
        vm.assertEq(results[1], 1);
        vm.assertEq(results[2], 1);
        {
            assertTakerOrders(ethPoolId, false, address(t1), 0);
            assertTakerOrders(ethPoolId, false, address(t2), 0);
            assertTakerOrders(usdPoolId, false, address(t3), 0);
            assertTakerOrders(usdPoolId, false, address(t4), 7);
            assertTakerOrders(ethPoolId, true, address(t1), 1);
            assertTakerOrders(ethPoolId, true, address(t2), 0);
            assertTakerOrders(usdPoolId, true, address(t3), 1);
            assertTakerOrders(usdPoolId, true, address(t4), 1);
        }

        results = updatePriceAndExecuteOrder(10, 80000e8, 2000e8, true);
        vm.assertEq(tp.executedOrderPosition(), 9);
        vm.assertEq(results.length, 5);
        vm.assertEq(results[0], 1);
        vm.assertEq(results[1], 1);
        vm.assertEq(results[2], 1);
        vm.assertEq(results[3], 1);
        vm.assertEq(results[4], 1);
        {
            assertTakerOrders(ethPoolId, false, address(t1), 0);
            assertTakerOrders(ethPoolId, false, address(t2), 0);
            assertTakerOrders(usdPoolId, false, address(t3), 0);
            assertTakerOrders(usdPoolId, false, address(t4), 2);
            assertTakerOrders(ethPoolId, true, address(t1), 1);
            assertTakerOrders(ethPoolId, true, address(t2), 0);
            assertTakerOrders(usdPoolId, true, address(t3), 1);
            assertTakerOrders(usdPoolId, true, address(t4), 6);
        }

        // cancel order
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidStatus.selector, 1));
        tp.cancelOrder(3, false);

        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidStatus.selector, 1));
        tp.cancelOrder(7, false);

        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.NotCancel.selector, 0));
        tp.cancelOrder(10, false);

        vm.startPrank(address(t4));
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.NotCancel.selector, 1740800300));
        tp.cancelOrder(10, false);


        vm.warp(1740800400);
        vm.expectEmit(address(tp));
        emit ITakerPlugin.CanceledOrder(address(t4), 10, false);
        tp.cancelOrder(10, false);
        assertTakerOrder(10, false, 2, 1, 0, address(t4));
        assertTakerOrders(usdPoolId, false, address(t4), 1);

        vm.expectEmit(address(tp));
        emit ITakerPlugin.CanceledOrder(address(t4), 3, true);
        tp.cancelOrder(3, true);
        assertTakerOrders(usdPoolId, true, address(t4), 5);

        vm.warp(1740801000);
        vm.expectEmit(address(tp));
        emit ITakerPlugin.CanceledOrder(address(t4), 11, false);
        tp.cancelOrder(11, false);
        vm.stopPrank();
        assertTakerOrder(11, false, 2, 1, 0, address(t4));
        assertTakerOrders(usdPoolId, false, address(t4), 0);

        // add margin
        IMarkets.Position memory p0 = markets.getPositionInfo(ethPoolId, address(t1), true);
        uint256 b = address(t1).balance;
        uint256 be = eth.balanceOf(address(t1));
        vm.startPrank(address(t1));
        tp.addMargin(ethPoolId, true, 1e17);
        vm.assertEq(address(t1).balance, b);
        vm.assertEq(be-1e17, eth.balanceOf(address(t1)));
        IMarkets.Position memory p1 = markets.getPositionInfo(ethPoolId, address(t1), true);
        vm.assertEq(p0.amount, p1.amount);
        vm.assertEq(p0.value, p1.value);
        vm.assertEq(p0.margin+1e19, p1.margin);

        tp.addMargin{value: 2e17}(ethPoolId, true, 2e17);
        vm.stopPrank();
        vm.assertEq(b-2e17, address(t1).balance);
        vm.assertEq(be-1e17, eth.balanceOf(address(t1)));
        p1 = markets.getPositionInfo(ethPoolId, address(t1), true);
        vm.assertEq(p0.amount, p1.amount);
        vm.assertEq(p0.value, p1.value);
        vm.assertEq(p0.margin+3e19, p1.margin);

        p0 = markets.getPositionInfo(usdPoolId, address(t3), false);
        b = usd.balanceOf(address(t3));
        vm.startPrank(address(t3));
        tp.addMargin(usdPoolId, false, 100e6);
        vm.stopPrank();
        p1 = markets.getPositionInfo(usdPoolId, address(t3), false);
        vm.assertEq(b-100e6, usd.balanceOf(address(t3)));
        vm.assertEq(p0.amount, p1.amount);
        vm.assertEq(p0.value, p1.value);
        vm.assertEq(p0.margin+100e20, p1.margin);

        // update tpsl
        vm.expectRevert(ITakerPlugin.InvalidDeadline.selector);
        tp.updateTpSl(2, 1301e7, 909e7, 1740780000);

        vm.expectRevert(ITakerPlugin.InvalidOrder.selector);
        tp.updateTpSl(2, 1301e7, 909e7, 1740801500);

        vm.startPrank(address(t4));
        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidStatus.selector, 2));
        tp.updateTpSl(3, 1301e7, 909e7, 1740801500);

        vm.expectEmit(address(tp));
        emit IPoolPlugin.UpdatedTpSl(address(t4), 4, 66000e10, 79000e10, 1740801500);
        tp.updateTpSl(4, 66000e10, 79000e10, 1740801500);
        tp.getOrderInfo(4, true);
        vm.stopPrank();

        // create tpsl
        ITakerPlugin.TpSlParams memory tsp = ITakerPlugin.TpSlParams({
            marketId: ethPoolId,
            taker: t0,
            direction: false,
            amount: 3e20,
            triggerType: 0,
            tp: 1922e10,
            sl: 1940e10,
            executionFee: 1e14,
            deadline: 1740801600
        });
        vm.startPrank(address(t2));
        vm.expectEmit(address(tp));
        emit ITakerPlugin.CreatedTpSl(ethPoolId, address(t2), false, 0, 3e20, 9, 1e14, 1740801600, 1922e10, 1940e10);
        (oid, isConditional) = tp.createTpSl{value: 1e14}(tsp);
        vm.assertEq(oid, 9);
        vm.assertEq(isConditional, true);
        assertTakerOrder(oid, isConditional, 0, 3, 0, address(t2));

        tsp.amount = 5e20;
        tsp.triggerType = 1;
        tsp.tp = 2120e10;
        tsp.sl = 0;
        vm.expectEmit(address(tp));
        emit ITakerPlugin.CreatedTpSl(ethPoolId, address(t2), false, 1, 5e20, 10, 1e14, 1740801600, 2120e10, 1e28);
        (oid, isConditional) = tp.createTpSl{value: 1e14}(tsp);
        vm.assertEq(oid, 10);
        vm.assertEq(isConditional, true);
        assertTakerOrder(oid, isConditional, 0, 3, 1, address(t2));
        vm.stopPrank();

        tsp.marketId = usdPoolId;
        tsp.amount = 1e20;
        tsp.tp = 0;
        tsp.sl = 79800e10;
        tsp.triggerType = 0;
        vm.startPrank(address(t3));
        vm.expectEmit(address(tp));
        emit ITakerPlugin.CreatedTpSl(usdPoolId, address(t3), false, 0, 1e20, 11, 1e14, 1740801600, 0, 79800e10);
        (oid, isConditional) = tp.createTpSl{value: 1e14}(tsp);
        vm.stopPrank();
        vm.assertEq(oid, 11);
        vm.assertEq(isConditional, true);
        assertTakerOrder(oid, isConditional, 0, 3, 0, address(t3));
        vm.stopPrank();


        // create remove order
        {
            vm.startPrank(address(t1));

            params.increaseParams.marketId = ethPoolId;
            params.increaseParams.amount = 3e20;
            params.increaseParams.direction = true;
            params.executionFee = 1e14;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedDecreaseOrder(ethPoolId, address(t1), true, false, 0, 12, 1e14, 0, 1740802000, 3e20);
            (oid, isConditional) = tp.createDecreaseOrder{value: 1e14}(params, 1740802000, 0);
            vm.assertEq(oid, 12);
            vm.assertEq(isConditional, false);

            params.increaseParams.amount = 5e20;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedDecreaseOrder(ethPoolId, address(t1), true, false, 0, 13, 1e14, 0, 1740802000, 5e20);
            (oid, isConditional) = tp.createDecreaseOrder{value: 1e14}(params, 1740802000, 0);
            vm.assertEq(oid, 13);
            vm.assertEq(isConditional, false);

            params.increaseParams.amount = 5e20;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedDecreaseOrder(ethPoolId, address(t1), true, false, 0, 14, 1e14, 0, 1740801500, 5e20);
            (oid, isConditional) = tp.createDecreaseOrder{value: 1e14}(params, 1740801500, 0);
            vm.assertEq(oid, 14);
            vm.assertEq(isConditional, false);

            vm.stopPrank();
        }

        {
            vm.startPrank(address(t3));
            params.increaseParams.marketId = usdPoolId;
            params.increaseParams.amount = 3e19;
            params.increaseParams.direction = false;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedDecreaseOrder(usdPoolId, address(t3), false, false, 0, 15, 1e14, 0, 1740802000, 3e19);
            (oid, isConditional) = tp.createDecreaseOrder{value: 1e14}(params, 1740802000, 0);
            vm.assertEq(oid, 15);
            vm.assertEq(isConditional, false);

            params.increaseParams.amount = 2e19;
            emit ITakerPlugin.CreatedDecreaseOrder(usdPoolId, address(t3), false, false, 0, 16, 1e14, 0, 1740801600, 2e19);
            (oid, isConditional) = tp.createDecreaseOrder{value: 1e14}(params, 1740801600, 0);
            vm.assertEq(oid, 16);
            vm.assertEq(isConditional, false);
        }

        vm.warp(1740801700);
        vm.startPrank(address(t1));
        tp.cancelOrder(14, false);
        vm.stopPrank();
        tp.cancelOrder(16, false);

        results = updatePriceAndExecuteOrder(10, 80300e8, 2030e8, true);
        vm.assertEq(results.length, 5);
        vm.assertEq(results[0], 3);
        vm.assertEq(results[1], 3);
        vm.assertEq(results[2], 1);
        vm.assertEq(results[3], 1);
        vm.assertEq(results[4], 3);

        results = updatePriceAndExecuteOrder(10, 80300e8, 2030e8, true);
        vm.assertEq(results.length, 2);
        vm.assertEq(results[0], 1);
        vm.assertEq(results[1], 3);
    }

    function testLiquidatePosition() public {
        usd.approve(address(markets), 1e18);

        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 100e6,
            amount: 1e18
        }));

        setPrice(btcId, 7040219e6);

        usd.mint(a2, 500e6);
        vm.startPrank(a2);
        usd.approve(address(markets), 1e18);
        markets.addMargin(usdPoolId, a2, true, 100e6);
        vm.stopPrank();

        vm.startPrank(a2);
        vm.expectRevert(IMarkets.InvalidCall.selector);
        markets.liquidate(usdPoolId, a2, address(this), true);
        vm.stopPrank();
        vm.expectRevert(IMarkets.NotLiquidate.selector);
        markets.liquidate(usdPoolId, a2, address(this), true);

        setPrice(btcId, 6030000e6);
        uint256 balance0 = usd.balanceOf(address(this));
        IMarkets.Position memory p = markets.getPositionInfo(usdPoolId, a2, true);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceAdded(usdPoolId, 1000227);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(usdPoolId, a2, true, address(this), p.margin, p.amount, p.value, 2412e16, -197181816e14, 200045454e12, 0);
        int256 marginBalance = updatePriceAndLiquidatePosition(usdPoolId, a2, true, 6030000e6, 2000e8, false);
        vm.assertEq(marginBalance, 256456, "MBE");
        vm.assertEq(im.userBalances(address(this), address(usd)), 5e6, "UBE");
        vm.assertEq(im.poolBalances(usdPoolId), 1000227, "PBE");
        assertTakerPosition(usdPoolId, a2, true, 0, 0, 0);
        vm.assertEq(usd.balanceOf(a2), 400e6+256456, "A2B");
        vm.assertEq(usd.balanceOf(address(this)), balance0+1000227, "IMB");
    }

    function updatePriceAndExecuteOrder(uint256 executeNum, int256 btcPrice, int256 ethPrice, bool updateOracle) public returns(uint8[] memory results) {
        bytes32[] memory priceIds = new bytes32[](2);
        priceIds[0] = btcId;
        priceIds[1] = ethId;
        bytes[] memory priceUpdateData = new bytes[](2);
        priceUpdateData[0] = abi.encode(priceInfos[btcId].pythId, btcPrice);
        priceUpdateData[1] = abi.encode(priceInfos[ethId].pythId, ethPrice);

        if (updateOracle) {
            TestOracle(priceInfos[btcId].oracle).updatePrice(btcPrice);
            TestOracle(priceInfos[ethId].oracle).updatePrice(ethPrice);
        }

        results = tp.updatePriceAndExecuteOrder{value: 2}(executeNum, priceIds, priceUpdateData);
    }

    function updatePriceAndExecuteConditionalOrder(uint256[] memory ids, int256 btcPrice, int256 ethPrice, bool updateOracle) public returns(uint8[] memory) {
        bytes32[] memory priceIds = new bytes32[](2);
        priceIds[0] = btcId;
        priceIds[1] = ethId;
        bytes[] memory priceUpdateData = new bytes[](2);
        priceUpdateData[0] = abi.encode(priceInfos[btcId].pythId, btcPrice);
        priceUpdateData[1] = abi.encode(priceInfos[ethId].pythId, ethPrice);

        if (updateOracle) {
            TestOracle(priceInfos[btcId].oracle).updatePrice(btcPrice);
            TestOracle(priceInfos[ethId].oracle).updatePrice(ethPrice);
        }

        return tp.updatePriceAndExecuteConditionalOrder{value: 2}(ids, priceIds, priceUpdateData);
    }

    function updatePriceAndLiquidatePosition(bytes32 marketId, address taker, bool direction, int256 btcPrice, int256 ethPrice, bool updateOracle) public returns(int256 marginBalance) {
        bytes32[] memory priceIds = new bytes32[](2);
        priceIds[0] = btcId;
        priceIds[1] = ethId;
        bytes[] memory priceUpdateData = new bytes[](2);
        priceUpdateData[0] = abi.encode(priceInfos[btcId].pythId, btcPrice);
        priceUpdateData[1] = abi.encode(priceInfos[ethId].pythId, ethPrice);

        if (updateOracle) {
            TestOracle(priceInfos[btcId].oracle).updatePrice(btcPrice);
            TestOracle(priceInfos[ethId].oracle).updatePrice(ethPrice);
        }

        (marginBalance, ,) = tp.updatePriceAndLiquidatePosition{value: 2}(marketId, taker, direction, priceIds, priceUpdateData);
    }

    function assertTakerOrder(uint256 orderId, bool isConditional, int8 status, int8 orderType, int8 triggerType, address taker) public view {
        ITakerPlugin.Order memory info = tp.getOrderInfo(orderId, isConditional);
        vm.assertEq(info.status, status);
        vm.assertEq(info.orderType, orderType);
        vm.assertEq(info.triggerType, triggerType);
        vm.assertEq(info.content.increaseParams.taker, taker);
    }

    function assertTakerOrders(bytes32 marketId, bool isConditional, address taker, uint256 num) public view {
        uint256[] memory orders;
        if (isConditional) orders = tp.getTakerConditionalOrders(taker, marketId);
        else orders = tp.getTakerOrders(taker, marketId);

        vm.assertEq(orders.length, num);
    }

    function assertTakerPosition(bytes32 marketId, address taker, bool direction, int256 amount, int256 value, int256 margin) private view {
        IMarkets.Position memory pos = markets.getPositionInfo(marketId, taker, direction);
        vm.assertGe(pos.amount, amount, "TPAG");
        vm.assertLt(pos.amount, amount+1e10, "TPAL");
        vm.assertGe(pos.margin, margin, "TPMG");
        vm.assertLt(pos.margin, margin+1e10, "TPMG");
        vm.assertGe(pos.value, value, "TPVG");
        vm.assertLt(pos.value, value+1e10, "TPVL");
    }


    receive() external payable {
        revert("Executor Attacking...");
    }

    fallback() external payable {
        revert("Executor FallBack Attacking...");
    }
}