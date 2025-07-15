// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./Init.sol";
import "../src/test/Trader.sol";
import "../src/plugin/PoolPlugin.sol";

contract PoolPluginTest is Init {
    PoolPlugin public pp;
    address public t0 = vm.addr(0xadd00ff001);
    Trader public t1;
    Trader public t2;
    Trader public t3;
    Trader public t4;

    function setUp() public {
        initial();

        pp = new PoolPlugin(address(eth), address(pools), address(ph), 1e14);
        pools.addPlugin(address(pp));

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
        eth.deposit{value: 50e18}();
        vm.stopPrank();

        t1.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t2.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t3.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t4.dos(address(usd), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));

        t1.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t2.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t3.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));
        t4.dos(address(eth), 0, abi.encodeWithSelector(IERC20.approve.selector, address(pp), 1e20));

        t1.dos(address(eth), 50e18, abi.encodeWithSelector(eth.deposit.selector));
        t2.dos(address(eth), 50e18, abi.encodeWithSelector(eth.deposit.selector));
        t3.dos(address(eth), 50e18, abi.encodeWithSelector(eth.deposit.selector));
        t4.dos(address(eth), 50e18, abi.encodeWithSelector(eth.deposit.selector));

        t1.dos(address(pools), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(pp), true));
        t2.dos(address(pools), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(pp), true));
        t3.dos(address(pools), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(pp), true));
        t4.dos(address(pools), 0, abi.encodeWithSelector(IPlugin.approve.selector, address(pp), true));

        pools.approve(address(this), true);

        vm.startPrank(address(t1));
        pools.approve(address(this), true);
        vm.stopPrank();
        vm.startPrank(address(t2));
        pools.approve(address(this), true);
        vm.stopPrank();
    }

    function testParams() public {
        vm.assertEq(pp.calcPoolId("ETH/USD", address(eth)), ethPoolId);
        vm.assertEq(pp.calcPoolId("ETH/USD", address(btc)), btcPoolId);
        vm.assertEq(pp.calcPoolId("BTC/USD", address(usd)), usdPoolId);

        IPoolPlugin.OrderParams memory params;
        params.amount = 2e20;
        params.margin = 1e17;
        params.maker = address(t1);
        params.executionFee = 0.0001 ether;
        params.executionPrice = 0;
        params.tp = 0;
        params.sl = 0;
        params.tpSlExecutionFee = 0.0001 ether;
        params.poolId = ethPoolId;

        vm.expectRevert(IPoolPlugin.InvalidDeadline.selector);
        pp.createAddOrder(params, block.timestamp + 200);

        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidExecutionFee.selector, 0.00009 ether));
        params.executionFee = 0.00009 ether;
        pp.createAddOrder(params, block.timestamp + 500);

        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidExecutionFee.selector, 0.00005 ether));
        params.executionFee = 0.0001 ether;
        params.sl = 989e7;
        params.tpSlExecutionFee = 0.00005 ether;
        pp.createAddOrder(params, block.timestamp + 500);

        vm.expectRevert(IPoolPlugin.InvalidAmount.selector);
        params.sl = 0;
        params.tpSlExecutionFee = 0;
        params.amount = 1e16-1;
        pp.createAddOrder(params, block.timestamp + 500);

        vm.expectRevert(IPoolPlugin.InvalidMargin.selector);
        params.amount = 2e20;
        params.margin = 1e16-1;
        pp.createAddOrder(params, block.timestamp + 500);

        vm.expectRevert(IPoolPlugin.InsufficientFee.selector);
        params.margin = 1e17;
        pp.createAddOrder(params, block.timestamp + 500);

        vm.expectRevert(IPoolPlugin.InsufficientFee.selector);
        pp.createAddOrder{value: 1e17}(params, block.timestamp + 500);

        vm.expectRevert(IPoolPlugin.InsufficientFee.selector);
        pp.createAddOrder{value: 0.00009 ether}(params, block.timestamp + 500);

        vm.expectRevert(IPoolPlugin.InsufficientFee.selector);
        params.tp = 1201e7;
        params.tpSlExecutionFee = 0.00015 ether;
        pp.createAddOrder{value: 0.0002 ether}(params, block.timestamp + 500);

        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidTpSl.selector, 1311e7, 1366e7));
        params.tp = 1311e7;
        params.sl = 1366e7;
        pp.createAddOrder{value: 0.0002 ether}(params, block.timestamp + 500);
        

        vm.expectRevert(IPoolPlugin.InvalidDeadline.selector);
        params.tp = 0;
        params.tpSlExecutionFee = 0;
        pp.createRemoveOrder(params, block.timestamp + 299);

        vm.expectRevert(IPoolPlugin.InvalidAmount.selector);
        params.amount = 0;
        pp.createRemoveOrder(params, block.timestamp + 350);


        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidExecutionFee.selector, 0.00009 ether));
        params.amount = 2e20;
        params.executionFee = 0.00009 ether;
        pp.createRemoveOrder(params, block.timestamp + 350);

        vm.expectRevert(IPoolPlugin.InsufficientFee.selector);
        params.executionFee = 0.0002 ether;
        pp.createRemoveOrder{value: 0.00018 ether}(params, block.timestamp + 350);

        vm.startPrank(address(t1));
        vm.expectRevert(IPoolPlugin.NotPosition.selector);
        pp.createRemoveOrder{value: 0.0002 ether}(params, block.timestamp + 350);
        vm.stopPrank();

        IPoolPlugin.TpSlParams memory tpp = IPoolPlugin.TpSlParams({
            poolId: usdPoolId,
            maker: address(t2),
            amount: 1e20,
            tp: 1210e7,
            sl: 978e7,
            executionFee: 0.00015 ether,
            deadline: block.timestamp
        });

        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidExecutionFee.selector, 0.00009 ether));
        tpp.executionFee = 0.00009 ether;
        pp.createTpSl(tpp);

        vm.expectRevert(IPoolPlugin.InsufficientFee.selector);
        tpp.executionFee = 0.00015 ether;
        pp.createTpSl{value: 0.00014 ether}(tpp);

        tpp.tp = 1003e7;
        tpp.sl = 1101e7;
        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidTpSl.selector, 1003e7, 1101e7));
        pp.createTpSl{value: 0.00015 ether}(tpp);

        tpp.sl = 982e7;
        vm.startPrank(address(t1));
        vm.expectRevert(IPoolPlugin.NotPosition.selector);
        pp.createTpSl{value: 0.00015 ether}(tpp);
        vm.stopPrank();
    }

    function testOrders() public {
        IPoolPlugin.OrderParams memory params = IPoolPlugin.OrderParams({
            poolId: ethPoolId,
            maker: address(t1),
            margin: 1e18,
            amount: 5e20,
            tp: 0,
            sl: 0,
            executionPrice: 0,
            executionFee: 2e14,
            tpSlExecutionFee: 0
        });
        uint8[] memory results;

        // t1 add eth liquidity
        {
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedAddOrder(ethPoolId, address(t1), false, 1, 2e14, 0,1740766100,1e18, 5e20);
            t1.dos(address(pp), 10002e14, abi.encodeWithSelector(IPoolPlugin.createAddOrder.selector, params, block.timestamp + 400));
            assertPoolOrder(1, false, 0, 1, address(t1));
            vm.assertEq(address(t1).balance, 50e18-10002e14);
            vm.assertEq(eth.balanceOf(address(t1)), 50e18);
            assertMakerOrders(ethPoolId, false, address(t1), 1);
        }
        
        // t1 add weth liquidity
        {
            params.tp = 12001000000;
            params.executionFee = 1e14;
            params.tpSlExecutionFee = 1e14;
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedAddOrder(ethPoolId, address(t1), false, 2, 1e14, 0,1740766100,1e18, 5e20);
            t1.dos(address(pp), 2e14, abi.encodeWithSelector(IPoolPlugin.createAddOrder.selector, params, block.timestamp + 400));
            assertPoolOrder(2, false, 0, 1, address(t1));
            vm.assertEq(address(t1).balance, 50e18-10004e14);
            vm.assertEq(eth.balanceOf(address(t1)), 49e18);
            assertMakerOrders(ethPoolId, false, address(t1), 2);
        }

        // t2 add usd liquidity
        {
            params.poolId = usdPoolId;
            params.amount = 10000e20;
            params.margin = 1000e6;
            params.tp = 0;
            params.executionFee = 1e14;
            params.tpSlExecutionFee = 1e14;
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedAddOrder(usdPoolId, address(t2), false, 3, 1e14, 0, 1740766100, 1000e6, 10000e20);
            t2.dos(address(pp), 1e14, abi.encodeWithSelector(IPoolPlugin.createAddOrder.selector, params, block.timestamp + 400));
            assertPoolOrder(3, false, 0, 1, address(t2));
            vm.assertEq(address(t2).balance, 50e18-1e14);
            vm.assertEq(eth.balanceOf(address(t2)), 50e18);
            vm.assertEq(usd.balanceOf(address(t2)), 9000e6);
            assertMakerOrders(usdPoolId, false, address(t2), 1);
        }

        // t3 add usd liquidity 8
        {
            params.poolId = usdPoolId;
            params.amount = 5000e20;
            params.margin = 200e6;
            params.tp = 1211e7;
            params.sl = 956e7;
            params.executionFee = 1e14;
            params.tpSlExecutionFee = 1e14;

            for (uint256 i=0; i<8; i++) {
                t3.dos(address(pp), 2e14, abi.encodeWithSelector(IPoolPlugin.createAddOrder.selector, params, block.timestamp + 400));
            }
            vm.assertEq(address(t3).balance, 50e18-16e14);
            vm.assertEq(eth.balanceOf(address(t3)), 50e18);
            vm.assertEq(usd.balanceOf(address(t3)), 8400e6);
            vm.assertEq(pp.executedOrderPosition(), 0);
            vm.assertEq(pp.getOrderNum(false), 11);
            vm.assertEq(pp.getOrderNum(true), 0);
            assertMakerOrders(usdPoolId, false, address(t3), 8);
        }

        assertMakerOrders(ethPoolId, true, address(t1), 0);
        assertMakerOrders(usdPoolId, true, address(t2), 0);
        assertMakerOrders(usdPoolId, true, address(t3), 0);

        // execute order
        vm.txGasPrice(10);
        results = pp.executeOrder(1);
        vm.assertEq(results.length, 1);
        vm.assertEq(results[0], 5);
        assertPoolOrder(1, false, 0, 1, address(t1));
        assertMakerOrders(ethPoolId, false, address(t1), 2);


        vm.warp(block.timestamp + 1);
        vm.expectEmit(address(pp));
        emit IPoolPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), false, 1, 1, 2e14, 1e10);
        results = pp.executeOrder(1);
        vm.assertEq(results.length, 1);
        vm.assertEq(results[0], 1);
        assertPoolOrder(1, false, 1, 1, address(t1));
        vm.assertEq(pp.executedOrderPosition(), 1);
        assertMakerOrders(ethPoolId, false, address(t1), 1);
        assertMakerOrders(usdPoolId, false, address(t2), 1);
        assertMakerOrders(usdPoolId, false, address(t3), 8);
        
        results = updatePriceAndExecuteOrder(3, 80010e8, 2000e8, false);
        vm.assertEq(results.length, 3);
        vm.assertEq(results[0], 1);
        vm.assertEq(results[1], 1);
        vm.assertEq(results[2], 1);
        vm.assertEq(pp.executedOrderPosition(), 4);
        assertMakerOrders(ethPoolId, false, address(t1), 0);
        assertMakerOrders(usdPoolId, false, address(t2), 0);
        assertMakerOrders(usdPoolId, false, address(t3), 7);
        assertMakerOrders(ethPoolId, true, address(t1), 1);
        assertMakerOrders(usdPoolId, true, address(t2), 0);
        assertMakerOrders(usdPoolId, true, address(t3), 1);

        results = updatePriceAndExecuteOrder(10, 80010e8, 2000e8, false);
        vm.assertEq(results.length, 5);
        vm.assertEq(results[0], 1);
        vm.assertEq(results[1], 1);
        vm.assertEq(results[2], 1);
        vm.assertEq(results[3], 1);
        vm.assertEq(results[4], 1);
        vm.assertEq(pp.executedOrderPosition(), 9);
        assertMakerOrders(ethPoolId, false, address(t1), 0);
        assertMakerOrders(usdPoolId, false, address(t2), 0);
        assertMakerOrders(usdPoolId, false, address(t3), 2);
        assertMakerOrders(ethPoolId, true, address(t1), 1);
        assertMakerOrders(usdPoolId, true, address(t2), 0);
        assertMakerOrders(usdPoolId, true, address(t3), 6);

        // cancel order
        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidStatus.selector, 1));
        pp.cancelOrder(3, false);

        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidStatus.selector, 1));
        pp.cancelOrder(7, false);

        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.NotCancel.selector, 0));
        pp.cancelOrder(10, false);

        vm.startPrank(address(t3));
        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.NotCancel.selector, 1740766000));
        pp.cancelOrder(10, false);

        vm.warp(1740766010);
        vm.expectEmit(address(pp));
        emit IPoolPlugin.CanceledOrder(address(t3), 10, false);
        pp.cancelOrder(10, false);
        assertPoolOrder(10, false, 2, 1, address(t3));
        assertMakerOrders(usdPoolId, false, address(t3), 1);

        vm.expectEmit(address(pp));
        emit IPoolPlugin.CanceledOrder(address(t3), 3, true);
        pp.cancelOrder(3, true);
        assertMakerOrders(usdPoolId, true, address(t3), 5);
        vm.stopPrank();

        vm.warp(1740766200);
        vm.expectEmit(address(pp));
        emit IPoolPlugin.CanceledOrder(address(t3), 11, false);
        pp.cancelOrder(11, false);
        assertPoolOrder(11, false, 2, 1, address(t3));
        assertMakerOrders(usdPoolId, false, address(t3), 0);
        assertMakerOrders(usdPoolId, true, address(t3), 5);


        // t0 add weth liquidity
        {
            params.poolId = ethPoolId;
            params.tp = 0;
            params.sl = 0;
            params.amount = 10e20;
            params.margin = 1e18;
            params.executionFee = 1e14;
            params.tpSlExecutionFee = 1e14;
            vm.startPrank(t0);
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedAddOrder(ethPoolId, address(t0), false, 12, 1e14, 0, 1740766550, 1e18, 10e20);
            pp.createAddOrder{value: 1e14}(params, block.timestamp + 350);
            vm.stopPrank();
            assertPoolOrder(12, false, 0, 1, address(t0));
            vm.assertEq(address(t0).balance, 50e18-1e14);
            vm.assertEq(eth.balanceOf(address(t0)), 49e18);
            assertMakerOrders(ethPoolId, false, address(t0), 1);
        }

        vm.txGasPrice(0);
        vm.warp(1740766600);
        vm.expectEmit(address(pp));
        emit IPoolPlugin.CanceledOrder(t0, 12, false);
        pp.cancelOrder(12, false);
        assertPoolOrder(12, false, 2, 1, t0);
        vm.assertEq(t0.balance, 51e18);
        vm.assertEq(eth.balanceOf(address(t0)), 49e18);

        IPools.Position memory p0 = pools.getPosition(ethPoolId, address(t1));
        // add margin
        vm.startPrank(address(t1));
        uint256 b = eth.balanceOf(address(t1));
        pp.addMargin(ethPoolId, 5e16);
        vm.assertEq(eth.balanceOf(address(t1)), b-5e16);
        vm.stopPrank();
        IPools.Position memory p1 = pools.getPosition(ethPoolId, address(t1));
        vm.assertEq(p0.margin + 5e18, p1.margin);
        vm.assertEq(p0.amount, p1.amount);
        vm.assertEq(p0.value, p1.value);

        vm.startPrank(address(t1));
        b = address(t1).balance;
        pp.addMargin{value: 7e16}(ethPoolId, 7e16);
        vm.assertEq(address(t1).balance, b-7e16);
        vm.stopPrank();
        p1 = pools.getPosition(ethPoolId, address(t1));
        vm.assertEq(p0.margin + 5e18+7e18, p1.margin);
        vm.assertEq(p0.amount, p1.amount);
        vm.assertEq(p0.value, p1.value);

        p0 = pools.getPosition(usdPoolId, address(t2));
        vm.startPrank(address(t2));
        b = usd.balanceOf(address(t2));
        pp.addMargin(usdPoolId, 100e6);
        vm.assertEq(usd.balanceOf(address(t2)), b-100e6);
        vm.stopPrank();
        p1 = pools.getPosition(usdPoolId, address(t2));
        vm.assertEq(p0.margin + 100e20, p1.margin);
        vm.assertEq(p0.amount, p1.amount);
        vm.assertEq(p0.value, p1.value);


        // update tpsl
        vm.expectRevert(IPoolPlugin.InvalidOrder.selector);
        pp.updateTpSl(2, 1301e7, 909e7, 1740780000);

        vm.startPrank(address(t3));
        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidStatus.selector, 2));
        pp.updateTpSl(3, 1301e7, 909e7, 1740780000);

        vm.expectRevert(abi.encodeWithSelector(IPoolPlugin.InvalidTpSl.selector, 1102e7, 1322e7));
        pp.updateTpSl(4,  1102e7, 1322e7, 1740780000);
        
        vm.expectEmit(address(pp));
        emit IPoolPlugin.UpdatedTpSl(address(t3), 4, 1301e7, 909e7, 1740780000);
        pp.updateTpSl(4, 1301e7, 909e7, 1740780000);
        pp.getOrderInfo(4, true);
        vm.stopPrank();

        // create tpsl
        IPoolPlugin.TpSlParams memory tsp = IPoolPlugin.TpSlParams({
            poolId: ethPoolId,
            maker: address(this),
            amount: 1e20,
            tp: 1403e7,
            sl: 970e7,
            executionFee: 1e14,
            deadline: 1740800000
        });
        vm.startPrank(address(t1));
        vm.expectEmit(address(pp));
        emit IPoolPlugin.CreatedTpSl(ethPoolId, address(t1), 1e20, 8, 1e14, 1740800000, 1403e7, 970e7);
        (uint256 tsId, bool ii) = pp.createTpSl{value: 1e14}(tsp);
        vm.assertEq(tsId, 8);

        tsp.tp = 1501e7;
        vm.expectEmit(address(pp));
        emit IPoolPlugin.CreatedTpSl(ethPoolId, address(t1), 1e20, 9, 1e14, 1740800000, 1501e7, 970e7);
        (tsId, ii) = pp.createTpSl{value: 1e14}(tsp);
        vm.assertEq(tsId, 9);

        tsp.tp = 1551e7;
        tsp.amount = 6e20;
        vm.expectEmit(address(pp));
        emit IPoolPlugin.CreatedTpSl(ethPoolId, address(t1), 6e20, 10, 1e14, 1740800000, 1551e7, 970e7);
        (tsId, ii) = pp.createTpSl{value: 1e14}(tsp);
        vm.assertEq(tsId, 10);
        vm.stopPrank();

        vm.startPrank(address(t3));
        tsp.poolId = usdPoolId;
        vm.expectEmit(address(pp));
        emit IPoolPlugin.CreatedTpSl(usdPoolId, address(t3), 6e20, 11, 1e14, 1740800000, 1551e7, 970e7);
        (tsId, ii) = pp.createTpSl{value: 1e14}(tsp);
        vm.assertEq(tsId, 11);
        vm.stopPrank();


        vm.warp(1741371000);

        // create remove order
        // t1 remove eth liquidity
        {
            params.poolId = ethPoolId;
            params.amount = 1e20;
            params.tp = 0;
            params.sl = 0;
            params.executionPrice = 0;
            params.executionFee = 3e14;
            b = address(t1).balance;
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedRemoveOrder(ethPoolId, address(t1), false, 13, 3e14, 0, 1741371500, 1e20);
            t1.dos(address(pp), 3e14, abi.encodeWithSelector(IPoolPlugin.createRemoveOrder.selector, params, 1741371500));
            assertPoolOrder(13, false, 0, 2, address(t1));
            vm.assertEq(address(t1).balance, b-3e14);
            assertMakerOrders(ethPoolId, false, address(t1), 1);
        }

        // t3 remove liquidity
        {
            params.poolId = usdPoolId;
            params.amount = 100e20;
            params.executionFee = 2e14;
            b = address(t3).balance;
            vm.startPrank(address(t3));
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedRemoveOrder(usdPoolId, address(t3), false, 14, 2e14, 0, 1741372200, 100e20);
            (uint256 oid, ) = pp.createRemoveOrder{value: 2e14}(params, 1741372200);
            vm.stopPrank();
            vm.assertEq(oid, 14);
            assertPoolOrder(14, false, 0, 2, address(t3));
            vm.assertEq(address(t3).balance, b-2e14);
            assertMakerOrders(usdPoolId, false, address(t3), 1);
        }

        // t1 remove eth liquidity
        {
            params.poolId = ethPoolId;
            params.amount = 3e20;
            params.executionFee = 1e14;
            b = address(t1).balance;
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedRemoveOrder(ethPoolId, address(t1), false, 15, 1e14, 0, 1741372100, 3e20);
            t1.dos(address(pp), 1e14, abi.encodeWithSelector(IPoolPlugin.createRemoveOrder.selector, params, 1741372100));
            assertPoolOrder(15, false, 0, 2, address(t1));
            vm.assertEq(address(t1).balance, b-1e14);
            assertMakerOrders(ethPoolId, false, address(t1), 2);
        }


        vm.warp(1741372000);
        vm.expectEmit(address(pp));
        emit IPoolPlugin.CanceledOrder(address(t1), 13, false);
        pp.cancelOrder(13, false);
        

        setPrice(btcId, 80000e8);
        setPrice(ethId, 2000e8);

        results = updatePriceAndExecuteOrder(10, 80020e8, 2001e8, false);
        vm.assertEq(results.length, 5);
        vm.assertEq(results[0], 3);
        vm.assertEq(results[1], 3);
        vm.assertEq(results[2], 3);
        vm.assertEq(results[3], 3);
        vm.assertEq(results[4], 1);

        vm.expectEmit(address(pp));
        emit IPoolPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), false, 15, 2, 1e14, 1e10);
        results = updatePriceAndExecuteOrder(10, 80020e8, 2001e8, false);
        vm.assertEq(results.length, 1);
        vm.assertEq(results[0], 1);
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

        results = pp.updatePriceAndExecuteOrder{value: 2}(executeNum, priceIds, priceUpdateData);
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

        return pp.updatePriceAndExecuteConditionalOrder{value: 2}(ids, priceIds, priceUpdateData);
    }

    function updatePriceAndLiquidateLiquidity(bytes32 poolId, address maker, int256 btcPrice, int256 ethPrice, bool updateOracle) public {
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

        pp.updatePriceAndLiquidateLiquidity{value: 2}(poolId, maker, priceIds, priceUpdateData);
    }

    function assertPoolOrder(uint256 orderId, bool isConditional, int8 status, int8 orderType, address maker) public view {
        IPoolPlugin.Order memory info = pp.getOrderInfo(orderId, isConditional);
        vm.assertEq(info.status, status);
        vm.assertEq(info.orderType, orderType);
        vm.assertEq(info.content.maker, maker);
    }

    function assertMakerOrders(bytes32 poolId, bool isConditional, address maker, uint256 num) public view {
        uint256[] memory orders;
        if (isConditional) orders = pp.getMakerConditionalOrders(maker, poolId);
        else orders = pp.getMakerOrders(maker, poolId);

        vm.assertEq(orders.length, num);
    }


    receive() external payable {
        revert("Executor Attacking...");
    }

    fallback() external payable {
        revert("Executor FallBack Attacking...");
    }
}