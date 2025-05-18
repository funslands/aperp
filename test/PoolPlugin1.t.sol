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
    }

    function testConditionalOrder() public {
        vm.warp(1740800000);
        IPoolPlugin.OrderParams memory params = IPoolPlugin.OrderParams({
            poolId: ethPoolId,
            maker: address(t1),
            margin: 1e18,
            amount: 5e20,
            tp: 0,
            sl: 0,
            executionPrice: 0,
            executionFee: 1e14,
            tpSlExecutionFee: 0
        });
        uint8[] memory results;

        // t1 add eth liquidity
        {
            params.amount = 10e20;
            params.margin = 1e18;
            params.executionPrice = 952e7;
            vm.startPrank(address(t1));
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedAddOrder(ethPoolId, address(t1), true, 1, 1e14, 952e7,1740800500,1e18, 10e20);
            (uint256 oid, bool isConditional) =  pp.createAddOrder{value: 10001e14}(params, block.timestamp + 500);
            vm.stopPrank();
            vm.assertEq(oid, 1);
            vm.assertEq(isConditional, true);
            
            assertPoolOrder(oid, isConditional, 0, 1, address(t1));
            vm.assertEq(address(t1).balance, 50e18-10001e14);
            vm.assertEq(eth.balanceOf(address(t1)), 50e18);
            assertMakerOrders(ethPoolId, true, address(t1), 1);
        }

        // t2 add eth liquidity
        {
            params.amount = 10e20;
            params.margin = 15e17;
            params.executionPrice = 973e7;
            params.tp = 1201e7;
            params.sl = 900e7;
            params.tpSlExecutionFee = 1e14;
            vm.startPrank(address(t2));
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedAddOrder(ethPoolId, address(t2), true, 2, 1e14, 973e7,1740800500,15e17, 10e20);
            (uint256 oid, bool isConditional) =  pp.createAddOrder{value: 2e14}(params, block.timestamp + 500);
            vm.stopPrank();
            vm.assertEq(oid, 2);
            vm.assertEq(isConditional, true);
            
            assertPoolOrder(oid, isConditional, 0, 1, address(t2));
            vm.assertEq(address(t2).balance, 50e18-2e14);
            vm.assertEq(eth.balanceOf(address(t2)), 50e18-15e17);
            assertMakerOrders(ethPoolId, true, address(t2), 1);
        }

        // t3 add eth liquidity
        {
            params.amount = 10e20;
            params.margin = 2e18;
            params.executionPrice = 923e7;
            params.tp = 1301e7;
            params.sl = 870e7;
            params.tpSlExecutionFee = 1e14;
            vm.startPrank(address(t3));
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedAddOrder(ethPoolId, address(t3), true, 3, 1e14, 923e7,1740800500,2e18, 10e20);
            (uint256 oid, bool isConditional) =  pp.createAddOrder{value: 2e14}(params, block.timestamp + 500);
            vm.stopPrank();
            vm.assertEq(oid, 3);
            vm.assertEq(isConditional, true);
            
            assertPoolOrder(oid, isConditional, 0, 1, address(t3));
            vm.assertEq(address(t3).balance, 50e18-2e14);
            vm.assertEq(eth.balanceOf(address(t3)), 48e18);
            assertMakerOrders(ethPoolId, true, address(t3), 1);

            vm.startPrank(address(t3));
            (oid, isConditional) =  pp.createAddOrder{value: 20002e14}(params, block.timestamp + 330);
            vm.stopPrank();
            vm.assertEq(oid, 4);
            vm.assertEq(isConditional, true);
            
            assertPoolOrder(oid, isConditional, 0, 1, address(t3));
            vm.assertEq(address(t3).balance, 50e18-20004e14);
            vm.assertEq(eth.balanceOf(address(t3)), 48e18);
            assertMakerOrders(ethPoolId, true, address(t3), 2);
        }



        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 4;
        results = updatePriceAndExecuteConditionalOrder(ids, 80000e8, 2000e8, true);
        vm.assertEq(results.length, 3);
        vm.assertEq(results[0], 5);
        vm.assertEq(results[1], 5);
        vm.assertEq(results[2], 5);

        vm.startPrank(t0);
        eth.approve(address(markets), 10e18);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: ethPoolId,
            taker: t0,
            direction: true,
            amount: 10e20,
            margin: 1e18
        }));
        vm.stopPrank();

        vm.warp(1740800300);
        setPrice(ethId, 2300e8);

        ids[0] = 2;
        ids[1] = 4;
        ids[2] = 1;
        vm.expectEmit(address(pp));
        emit IPoolPlugin.CreatedTpSl(ethPoolId, address(t2), 10e20, 5, 1e14, block.timestamp + 30 days, 1201e7, 900e7);
        emit IPoolPlugin.ExecutedOrder(ethPoolId, address(this), address(t2), true, 2, 1, 1e14, 9479495736);
        emit IPoolPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), true, 1, 1, 1e14, 9479495736);
        results = updatePriceAndExecuteConditionalOrder(ids, 80100e8, 2300e8, false);
        vm.assertEq(results.length, 3);
        vm.assertEq(results[0], 1);
        vm.assertEq(results[1], 6);
        vm.assertEq(results[2], 1);

        assertPoolOrder(5, true, 0, 3, address(t2));

        vm.warp(1740801000);
        setPrice(ethId, 2300e8);
        vm.expectEmit(address(pp));
        emit IPoolPlugin.CanceledOrder(address(t3), 3, true);
        pp.cancelOrder(3, true);
        vm.assertEq(address(t3).balance, 50e18-20004e14);
        vm.assertEq(eth.balanceOf(address(t3)), 500002e14);
        assertMakerOrders(ethPoolId, true, address(t3), 1);

        vm.expectEmit(address(pp));
        emit IPoolPlugin.CanceledOrder(address(t3), 4, true);
        pp.cancelOrder(4, true);
        vm.assertEq(eth.balanceOf(address(t3)), 520004e14);

        // tp remove liquidity
        {
            vm.startPrank(address(t1));
            params.amount = 5e20;
            params.executionPrice = 0;
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedRemoveOrder(ethPoolId, address(t1), false, 1, 1e14, 0, 1740802000, 5e20);
            pp.createRemoveOrder{value: 1e14}(params, 1740802000);

            params.amount = 7e20;
            params.executionPrice = 1060e7;
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedRemoveOrder(ethPoolId, address(t1), true, 6, 1e14, 1060e7, 1740802000, 7e20);
            pp.createRemoveOrder{value: 1e14}(params, 1740802000);

            vm.assertEq(address(t1).balance, 50e18-10003e14);
            vm.stopPrank();
        }
        
        vm.warp(1740801100);
        setPrice(ethId, 700e8);
        vm.expectEmit(address(pp));
        emit IPoolPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), false, 1, 2, 1e14, 11765249674);
        updatePriceAndExecuteOrder(10, 83000e8, 700e8, false);

        setPrice(ethId, 700e8);
        ids[0] = 6;
        ids[1] = 3;
        ids[2] = 5;
        vm.expectEmit(address(pp));
        emit IPoolPlugin.ExecutedOrder(ethPoolId, address(t4), address(t1), true, 6, 2, 1e14, 11768480443);
        vm.startPrank(address(t4));
        results = updatePriceAndExecuteConditionalOrder(ids, 83000e8, 700e8, false);
        vm.stopPrank();
        vm.assertEq(results[0], 1);
        vm.assertEq(results[1], 3);
        vm.assertEq(results[2], 6);

        setPrice(ethId, 600e8);
        ids[0] = 6;
        ids[1] = 3;
        ids[2] = 5;
        results = updatePriceAndExecuteConditionalOrder(ids, 83000e8, 600e8, false);
        vm.assertEq(results[0], 3);
        vm.assertEq(results[1], 3);
        vm.assertEq(results[2], 6);

        setPrice(ethId, 300e8);
        vm.expectEmit(address(pp));
        emit IPoolPlugin.ExecutedOrder(ethPoolId, address(this), address(t2), true, 5, 3, 1e14, 12438916341);
        results = updatePriceAndExecuteConditionalOrder(ids, 83000e8, 300e8, false);
        vm.assertEq(results[0], 3);
        vm.assertEq(results[1], 3);
        vm.assertEq(results[2], 1);

        
        assertPosition(ethPoolId, address(t1), 0, 0, 0, 1740800300, false);
        assertPosition(ethPoolId, address(t2), 0, 0, 0, 1740800300, false);

        // t1 add eth liquidity
        {
            params.amount = 15e20;
            params.margin = 2e18;
            params.executionPrice = 1100e7;
            params.tp = 0;
            params.sl = 970e7;
            params.tpSlExecutionFee = 1e14;
            vm.startPrank(address(t1));
            vm.expectEmit(address(pp));
            emit IPoolPlugin.CreatedAddOrder(ethPoolId, address(t1), true, 7, 1e14, 1100e7, 1740801600,2e18, 15e20);
            (uint256 oid, bool isConditional) =  pp.createAddOrder{value: 2e14}(params, block.timestamp + 500);
            vm.stopPrank();
            vm.assertEq(oid, 7);
            vm.assertEq(isConditional, true);
            
            assertPoolOrder(oid, isConditional, 0, 1, address(t1));
            assertMakerOrders(ethPoolId, true, address(t1), 1);
        }

        vm.warp(1740801500);
        setPrice(ethId, 1300e8);

        ids[0] = 7;
        ids[1] = 6;
        ids[2] = 5;
        vm.expectEmit(address(pp));
        emit IPoolPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), true, 7, 1, 1e14, 10443116341);
        results = updatePriceAndExecuteConditionalOrder(ids, 83000e8, 1300e8, false);
        vm.assertEq(results[0], 1);
        vm.assertEq(results[1], 3);
        vm.assertEq(results[2], 3);
        assertPosition(ethPoolId, address(t1), 15e20, 1566467451150000000000, 2e20, 1740801500, false);


        vm.warp(1740801600);
        ids[0] = 8;
        ids[1] = 6;
        ids[2] = 7;
        results = updatePriceAndExecuteConditionalOrder(ids, 83000e8, 1300e8, true);
        vm.assertEq(results[0], 6);
        vm.assertEq(results[1], 3);
        vm.assertEq(results[2], 3);

        setPrice(ethId, 2000e8);
        vm.expectEmit(address(pp));
        emit IPoolPlugin.ExecutedOrder(ethPoolId, address(this), address(t1), true, 8, 3, 1e14, 9366256935);
        results = updatePriceAndExecuteConditionalOrder(ids, 83000e8, 2000e8, false);
        vm.assertEq(results[0], 1);
        vm.assertEq(results[1], 3);
        vm.assertEq(results[2], 3);
        assertPosition(ethPoolId, address(t1), 0, 0, 0, 1740801500, false);
        
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

    function assertPosition(bytes32 poolId, address maker, int256 amount, int256 value, int256 margin, uint256 increaseTime, bool initial) private view {
        IPools.Position memory pos = pools.getPosition(poolId, maker);
        vm.assertEq(pos.amount, amount, "MPA");
        vm.assertEq(pos.margin, margin, "MPM");
        vm.assertEq(pos.value, value, "MPV");
        vm.assertEq(pos.increaseTime, increaseTime, "MPT");
        vm.assertEq(pos.initial, initial, "MPI");
    }


    receive() external payable {
        revert("Executor Attacking...");
    }

    fallback() external payable {
        revert("Executor FallBack Attacking...");
    }
}