// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./Init.sol";
import "../src/test/Trader.sol";
import "../src/plugin/PoolPlugin.sol";
import "../src/plugin/TakerPlugin.sol";

contract TakerPlugin1Test is Init {
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
        pools.approve(address(t0), true);
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

    function testConditionalOrder() public {
        vm.startPrank(t0);
        eth.approve(address(pools), 1e20);
        pools.addLiquidity(ethPoolId, t0, 20e18, 50e20);
        vm.stopPrank();
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
            executionFee: 1e14,
            tpSlExecutionFee: 1e14
        });

        // t1 create eth long order
        {
            vm.startPrank(address(t1));

            params.executionPrice = 1998e10;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedIncreaseOrder(ethPoolId, address(t1), true, true, 0, 1, 1e14, 1998e10, 1740802000, 1e18, 5e20);
            (oid, isConditional) = tp.createIncreaseOrder{value: 1e14}(params, 1740802000, 0);
            vm.assertEq(oid, 1);
            vm.assertEq(isConditional, true);

            params.increaseParams.amount = 7e20;
            params.increaseParams.margin = 1e18;
            params.executionPrice = 1990e10;
            params.tp = 2050e10;
            params.sl = 0;
            params.tpSlExecutionFee = 1e14;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedIncreaseOrder(ethPoolId, address(t1), true, true, 0, 2, 1e14, 1990e10, 1740802000, 1e18, 7e20);
            (oid, isConditional) = tp.createIncreaseOrder{value: 10002e14}(params, 1740802000, 0);
            vm.assertEq(oid, 2);
            vm.assertEq(isConditional, true);

            vm.assertEq(address(t1).balance, 50e18-10003e14);
            vm.assertEq(eth.balanceOf(address(t1)), 49e18);
            vm.stopPrank();
        }

        // t2 create eth short order
        {
            vm.startPrank(address(t2));

            params.executionPrice = 2002e10;
            params.increaseParams.direction = false;
            params.increaseParams.amount = 3e20;
            params.increaseParams.margin = 5e17;
            params.tp = 0;
            params.sl = 0;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedIncreaseOrder(ethPoolId, address(t2), false, true, 1, 3, 1e14, 2002e10, 1740802200, 5e17, 3e20);
            (oid, isConditional) = tp.createIncreaseOrder{value: 1e14}(params, 1740802200, 1);
            vm.assertEq(oid, 3);
            vm.assertEq(isConditional, true);

            params.increaseParams.amount = 9e20;
            params.increaseParams.margin = 12e17;
            params.executionPrice = 2056e10;
            params.tp = 1920e10;
            params.sl = 2070e10;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedIncreaseOrder(ethPoolId, address(t2), false, true, 0, 4, 1e14, 2056e10, 1740802300, 12e17, 9e20);
            (oid, isConditional) = tp.createIncreaseOrder{value: 12002e14}(params, 1740802300, 0);
            vm.assertEq(oid, 4);
            vm.assertEq(isConditional, true);

            vm.assertEq(address(t2).balance, 50e18-12003e14);
            vm.assertEq(eth.balanceOf(address(t2)), 495e17);

            vm.stopPrank();
        }

        // exec
        {
            uint256[] memory ids = createIds(4);
            ids[0] = 1;
            ids[1] = 3;
            ids[2] = 2;
            ids[3] = 4;
            results = tp.executeConditionalOrder(ids);
            vm.assertEq(results.length, 4);
            vm.assertEq(results[0], 5);
            vm.assertEq(results[1], 5);
            vm.assertEq(results[2], 5);
            vm.assertEq(results[3], 5);
        }

        vm.warp(block.timestamp + 1);
        // exec
        {
            uint256[] memory ids = createIds(4);
            ids[0] = 1;
            ids[1] = 3;
            ids[2] = 2;
            ids[3] = 4;
            results = tp.executeConditionalOrder(ids);
            vm.assertEq(results.length, 4);
            vm.assertEq(results[0], 6);
            vm.assertEq(results[1], 6);
            vm.assertEq(results[2], 6);
            vm.assertEq(results[3], 6);
        }

        // exec
        setPrice(ethId, 1998e8);
        {
            uint256[] memory ids = createIds(4);
            ids[0] = 3;
            ids[1] = 1;
            ids[2] = 4;
            ids[3] = 2;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), true, 1, 1, 1e14, 0, 1, 1998e10);
            results = updatePriceAndExecuteConditionalOrder(ids, 80000e8, 1998e8, false);
            vm.assertEq(results.length, 4);
            vm.assertEq(results[0], 6);
            vm.assertEq(results[1], 1);
            vm.assertEq(results[2], 6);
            vm.assertEq(results[3], 6);
        }

        // exec
        {
            vm.startPrank(t0);
            uint256[] memory ids = createIds(4);
            ids[0] = 2;
            ids[1] = 1;
            ids[2] = 4;
            ids[3] = 3;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(t0), address(t2), true, 3, 1, 1e14, 1, 1, 20149830000000);
            results = tp.executeConditionalOrder(ids);
            vm.assertEq(results.length, 4);
            vm.assertEq(results[0], 6);
            vm.assertEq(results[1], 3);
            vm.assertEq(results[2], 6);
            vm.assertEq(results[3], 1);
            vm.stopPrank();
        }

        // t1 create order
        {
            vm.startPrank(address(t1));
            params.increaseParams.amount = 8e20;
            params.increaseParams.margin = 2e18;
            params.executionPrice = 2020e10;
            params.tp = 1960e10;
            params.sl = 2060e10;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedIncreaseOrder(ethPoolId, address(t1), false, true, 0, 5, 1e14, 2020e10, 1740802200, 2e18, 8e20);
            (oid, isConditional) = tp.createIncreaseOrder{value: 2e14}(params, 1740802200, 0);
            vm.assertEq(oid, 5);
            vm.assertEq(isConditional, true);

            assertTakerOrders(ethPoolId, true, address(t1), 2);
        }

        // t2 create order
        {
            vm.startPrank(address(t2));
            params.increaseParams.amount = 4e20;
            params.increaseParams.margin = 5e17;
            params.increaseParams.direction = true;
            params.executionPrice = 1988e10;
            params.tp = 0;
            params.sl = 1920e10;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedIncreaseOrder(ethPoolId, address(t2), true, true, 1, 6, 1e14, 1988e10, 1740802100, 5e17, 4e20);
            (oid, isConditional) = tp.createIncreaseOrder{value: 2e14}(params, 1740802100, 1);
            vm.assertEq(oid, 6);
            vm.assertEq(isConditional, true);

            assertTakerOrders(ethPoolId, true, address(t2), 2);
            vm.stopPrank();
        }

        // exec
        vm.warp(1740801000);
        setPrice(ethId, 2020e8+1);
        {
            uint256[] memory ids = createIds(4);
            ids[0] = 5;
            ids[1] = 4;
            ids[2] = 6;
            ids[3] = 2;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedTpSl(ethPoolId, address(t1), false, 0, 8e20, 7, 1e14, block.timestamp + 30 days, 1960e10, 2060e10);
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), true, 5, 1, 1e14, 0, 1, 2020e10);
            results = tp.executeConditionalOrder(ids);
            vm.assertEq(results.length, 4);
            vm.assertEq(results[0], 1);
            vm.assertEq(results[1], 6);
            vm.assertEq(results[2], 6);
            vm.assertEq(results[3], 6);

            assertTakerOrders(ethPoolId, true, address(t1), 2);
            assertTakerOrders(ethPoolId, true, address(t2), 2);
        }

        setPrice(ethId, 2000e8+1);
        {
            uint256[] memory ids = createIds(4);
            ids[0] = 5;
            ids[1] = 4;
            ids[2] = 6;
            ids[3] = 2;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedTpSl(ethPoolId, address(t2), true, 1, 4e20, 8, 1e14, block.timestamp + 30 days, 1e28, 1920e10);
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t2), true, 6, 1, 1e14, 1, 1, 19721933468097);
            results = tp.executeConditionalOrder(ids);
            vm.assertEq(results.length, 4);
            vm.assertEq(results[0], 3);
            vm.assertEq(results[1], 6);
            vm.assertEq(results[2], 1);
            vm.assertEq(results[3], 6);

            assertTakerOrders(ethPoolId, true, address(t1), 2);
            assertTakerOrders(ethPoolId, true, address(t2), 2);
        }

        // test update tpsl
        vm.startPrank(address(t2));
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidTpSl.selector, 2072e10, 2088e10));
        tp.updateTpSl(8, 2072e10, 2088e10, 1740803000);
        vm.stopPrank();

        vm.startPrank(address(t1));
        vm.expectRevert(abi.encodeWithSelector(ITakerPlugin.InvalidTpSl.selector, 1920e10, 1918e10));
        tp.updateTpSl(7, 1920e10, 1918e10, 1740803000);
        vm.stopPrank();

        // exec
        setPrice(ethId, 1990e8);
        {
            uint256[] memory ids = createIds(1);
            ids[0] = 2;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedTpSl(ethPoolId, address(t1), true, 0, 7e20, 9, 1e14, block.timestamp + 30 days, 2050e10, 0);
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), true, 2, 1, 1e14, 0, 1, 1990e10);
            results = tp.executeConditionalOrder(ids);
            vm.assertEq(results.length, 1);
            vm.assertEq(results[0], 1);

            assertTakerOrders(ethPoolId, true, address(t1), 2);
            assertTakerOrders(ethPoolId, true, address(t2), 2);
        }

        // exec
        setPrice(ethId, 2060e8);
        {
            uint256[] memory ids = createIds(1);
            ids[0] = 4;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedTpSl(ethPoolId, address(t2), false, 0, 9e20, 10, 1e14, block.timestamp + 30 days, 1920e10, 2070e10);
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t2), true, 4, 1, 1e14, 0, 1, 2060e10);
            results = updatePriceAndExecuteConditionalOrder(ids, 80000e8, 2060e8, false);
            vm.assertEq(results.length, 1);
            vm.assertEq(results[0], 1);

            assertTakerOrders(ethPoolId, true, address(t1), 2);
            assertTakerOrders(ethPoolId, true, address(t2), 2);
        }

        // exec
        setPrice(ethId, 1930e8);
        {
            uint256[] memory ids = createIds(4);
            ids[0] = 7;
            ids[1] = 8;
            ids[2] = 9;
            ids[3] = 10;
            results = updatePriceAndExecuteConditionalOrder(ids, 80000e8, 1930e8, false);
            vm.assertEq(results.length, 4);
            vm.assertEq(results[0], 5);
            vm.assertEq(results[1], 5);
            vm.assertEq(results[2], 5);
            vm.assertEq(results[3], 5);
        }

        vm.warp(1740802000);
        setPrice(ethId, 1930e8);
        {
            uint256[] memory ids = createIds(4);
            ids[0] = 8;
            ids[1] = 7;
            ids[2] = 9;
            ids[3] = 10;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t2), true, 8, 3, 1e14, 1, 1, 19174550000000);
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t2), true, 7, 3, 1e14, 0, 1, 1930e10);
            results = tp.executeConditionalOrder(ids);
            vm.assertEq(results.length, 4);
            vm.assertEq(results[0], 1);
            vm.assertEq(results[1], 1);
            vm.assertEq(results[2], 6);
            vm.assertEq(results[3], 6);

            assertTakerOrders(ethPoolId, true, address(t1), 1);
            assertTakerOrders(ethPoolId, true, address(t2), 1);
            vm.stopPrank();
        }

        // exec
        setPrice(ethId, 2061e8);
        {
            uint256[] memory ids = createIds(4);
            ids[0] = 7;
            ids[1] = 8;
            ids[2] = 9;
            ids[3] = 10;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), true, 9, 3, 1e14, 0, 1, 2061e10);
            results = updatePriceAndExecuteConditionalOrder(ids, 80000e8, 2061e8, false);
            vm.assertEq(results.length, 4);
            vm.assertEq(results[0], 3);
            vm.assertEq(results[1], 3);
            vm.assertEq(results[2], 1);
            vm.assertEq(results[3], 6);

            assertTakerOrders(ethPoolId, true, address(t1), 0);
            assertTakerOrders(ethPoolId, true, address(t2), 1);
            vm.stopPrank();
        }

        // exec
        setPrice(ethId, 2071e8);
        {
            uint256[] memory ids = createIds(4);
            ids[0] = 7;
            ids[1] = 8;
            ids[2] = 9;
            ids[3] = 10;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t2), true, 10, 3, 1e14, 0, 1, 2071e10);
            results = updatePriceAndExecuteConditionalOrder(ids, 80000e8, 2071e8, false);
            vm.assertEq(results.length, 4);
            vm.assertEq(results[0], 3);
            vm.assertEq(results[1], 3);
            vm.assertEq(results[2], 3);
            vm.assertEq(results[3], 1);

            assertTakerOrders(ethPoolId, true, address(t1), 0);
            assertTakerOrders(ethPoolId, true, address(t2), 0);
            vm.stopPrank();
        }

        // create remove order
        {
            vm.startPrank(address(t1));

            params.increaseParams.amount = 7e20;
            params.increaseParams.direction = true;
            params.executionPrice = 2040e10;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedDecreaseOrder(ethPoolId, address(t1), true, true, 1, 11, 1e14, 2040e10, 1740803000, 7e20);
            (oid, isConditional) = tp.createDecreaseOrder{value: 1e14}(params, 1740803000, 1);
            vm.assertEq(oid, 11);
            vm.assertEq(isConditional, true);

            assertTakerOrders(ethPoolId, true, address(t1), 1);
            vm.stopPrank();
        }

        {
            vm.startPrank(address(t2));

            params.increaseParams.amount = 7e20;
            params.increaseParams.direction = false;
            params.executionPrice = 1940e10;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.CreatedDecreaseOrder(ethPoolId, address(t2), false, true, 0, 12, 1e14, 1940e10, 1740803000, 7e20);
            (oid, isConditional) = tp.createDecreaseOrder{value: 1e14}(params, 1740803000, 0);
            vm.assertEq(oid, 12);
            vm.assertEq(isConditional, true);

            assertTakerOrders(ethPoolId, true, address(t2), 1);
            vm.stopPrank();
        }

        // exec
        vm.warp(1740802500);
        setPrice(ethId, 1920e8);
        {
            uint256[] memory ids = createIds(2);
            ids[0] = 11;
            ids[1] = 12;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t2), true, 12, 2, 1e14, 0, 1, 19200000000000);
            results = tp.executeConditionalOrder(ids);
            vm.assertEq(results.length, 2);
            vm.assertEq(results[0], 6);
            vm.assertEq(results[1], 1);

            assertTakerOrders(ethPoolId, true, address(t1), 1);
            assertTakerOrders(ethPoolId, true, address(t2), 0);
            vm.stopPrank();
        }

        setPrice(ethId, 2040e8);
        {
            uint256[] memory ids = createIds(2);
            ids[0] = 11;
            ids[1] = 12;
            vm.expectEmit(address(tp));
            emit ITakerPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), true, 11, 2, 1e14, 1, 1, 20573400000000);
            results = updatePriceAndExecuteConditionalOrder(ids, 80000e8, 2040e8, false);
            vm.assertEq(results.length, 2);
            vm.assertEq(results[0], 1);
            vm.assertEq(results[1], 3);

            assertTakerOrders(ethPoolId, true, address(t1), 0);
            assertTakerOrders(ethPoolId, true, address(t2), 0);
            vm.stopPrank();
        }

        assertTakerPosition(ethPoolId, address(t1), true, 0, 0, 0);
        assertTakerPosition(ethPoolId, address(t1), false, 0, 0, 0);
        assertTakerPosition(ethPoolId, address(t2), true, 0, 0, 0);
        assertTakerPosition(ethPoolId, address(t2), false, 0, 0, 0);
    }

    function createIds(uint256 num) public pure returns(uint256[] memory ids) {
        return ids = new uint256[](num);
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