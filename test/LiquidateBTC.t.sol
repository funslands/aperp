// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./Init.sol";


/// test btc pool & markets 
contract LiquidateBTCTest is Init {
    address l1 = vm.addr(0xaafff011);
    address l2 = vm.addr(0xaafff012);
    address l3 = vm.addr(0xaafff013);
    address t1 = vm.addr(0xaafff014);
    address t2 = vm.addr(0xaafff015);

    function setUp() public {
        initial();

        pools.addPlugin(a1);
        pools.addPlugin(a2);
        pools.addPlugin(l1);
        pools.addPlugin(l2);
        pools.addPlugin(t1);
        pools.addPlugin(t2);
        markets.addPlugin(address(this));
        markets.addPlugin(a1);
        markets.addPlugin(a2);
        markets.addPlugin(l1);
        markets.addPlugin(l2);
        markets.addPlugin(t1);
        markets.addPlugin(t2);

        markets.approve(address(this), true);
        vm.startPrank(a1);
        pools.approve(a1, true);
        markets.approve(a1, true);
        pools.approve(address(this), true);
        markets.approve(address(this), true);
        vm.stopPrank();
        vm.startPrank(a2);
        pools.approve(a2, true);
        markets.approve(a2, true);
        pools.approve(address(this), true);
        markets.approve(address(this), true);
        vm.stopPrank();

        vm.startPrank(t1);
        pools.approve(t1, true);
        markets.approve(t1, true);
        pools.approve(address(this), true);
        markets.approve(address(this), true);
        vm.stopPrank();
        vm.startPrank(t2);
        pools.approve(t2, true);
        markets.approve(t2, true);
        pools.approve(address(this), true);
        markets.approve(address(this), true);
        vm.stopPrank();

        vm.startPrank(l1);
        pools.approve(l1, true);
        markets.approve(l1, true);
        pools.approve(address(this), true);
        markets.approve(address(this), true);
        vm.stopPrank();
        vm.startPrank(l2);
        pools.approve(l2, true);
        markets.approve(l2, true);
        pools.approve(address(this), true);
        markets.approve(address(this), true);
        vm.stopPrank();
    }

    // test liquidate taker short position 0
    function testLiquidateBtcPoolTS0() public {
        btc.approve(address(markets), 1e18);

        assertLiquidatePrice(btcPoolId, a2, true, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: false,
            margin: 1e7,
            amount: 1e20
        }));
        assertLiquidatePrice(btcPoolId, a2, false, false, 2080838e7);

        setPrice(ethId, 2081e8);
        assertLiquidatePrice(btcPoolId, a2, false, true, 2080838e7);

        btc.mint(a2, 5e7);
        vm.startPrank(a2);
        btc.approve(address(markets), 1e18);
        markets.addMargin(btcPoolId, a2, false, 1e7);
        vm.stopPrank();
        assertLiquidatePrice(btcPoolId, a2, false, false, 2180341e7);
        assertPoolStatus(btcPoolId, false, 1e20, 199204000000000000000000, 1992031840000000000);

        vm.startPrank(a2);
        vm.expectRevert(IMarkets.InvalidCall.selector);
        markets.liquidate(btcPoolId, a2, address(this), false);
        vm.stopPrank();
        vm.expectRevert(IMarkets.NotLiquidate.selector);
        markets.liquidate(btcPoolId, a2, address(this), false);

        setPrice(ethId, 2181e8);
        uint256 balance0 = btc.balanceOf(address(this));
        IMarkets.Position memory p = markets.getPositionInfo(btcPoolId, a2, false);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceAdded(btcPoolId, 249005);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(btcPoolId, a2, false, address(this), p.margin, p.amount, p.value, 8724e12, -18896e14, 49801e12, 0);
        (int256 marginBalance, , ) = markets.liquidate(btcPoolId, a2, address(this), false);
        vm.assertEq(marginBalance, 439068, "MBE");
        vm.assertEq(im.userBalances(address(this), address(btc)), 100000, "UBE");
        vm.assertEq(im.poolBalances(btcPoolId), 249005, "PBE");
        assertTakerPosition(btcPoolId, a2, false, 0, 0, 0, 0, 0);
        // fund to plugin[this]
        vm.assertEq(btc.balanceOf(a2), 4e7, "A2B");
        vm.assertEq(btc.balanceOf(address(this)), balance0+249005+439068, "IMB");
    }

    // test liquidate taker short position 1
    function testLiquidateBtcPoolTS1() public {
        btc.approve(address(markets), 1e18);

        assertLiquidatePrice(btcPoolId, a2, false, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: false,
            margin: 1e7,
            amount: 1e20
        }));
        assertLiquidatePrice(btcPoolId, a2, false, false, 2080838e7);

        btc.mint(a2, 5e7);
        vm.startPrank(a2);
        btc.approve(address(markets), 1e18);
        markets.addMargin(btcPoolId, a2, false, 1e7);
        vm.stopPrank();
        assertLiquidatePrice(btcPoolId, a2, false, false, 2180341e7);
        assertPoolStatus(btcPoolId, false, 1e20, 199204000000000000000000, 1992031840000000000);


        vm.startPrank(a2);
        vm.expectRevert(IMarkets.InvalidCall.selector);
        markets.liquidate(btcPoolId, a2, address(this), false);
        vm.stopPrank();
        vm.expectRevert(IMarkets.NotLiquidate.selector);
        markets.liquidate(btcPoolId, a2, address(this), false);

        setPrice(ethId, 2190e8);

        IMarkets.Position memory p = markets.getPositionInfo(btcPoolId, a2, false);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceAdded(btcPoolId, 36718);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(btcPoolId, a2, false, address(this), p.margin, p.amount, p.value, 876e13, -19796e14, 367184e10, 0);
        (int256 marginBalance, , ) = markets.liquidate(btcPoolId, a2, address(this), false);
        vm.assertEq(marginBalance, 0, "MBE");
        vm.assertEq(im.userBalances(address(this), address(btc)), 100000, "UBE");
        vm.assertEq(im.poolBalances(btcPoolId), 36718, "PBE");
        assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
        vm.assertEq(btc.balanceOf(a2), 4e7, "A2B");
    }

    // test liquidate taker short position 2
    function testLiquidateBtcPoolTS2() public {
        btc.approve(address(markets), 1e18);
        btc.mint(a2, 5e7);

        assertLiquidatePrice(btcPoolId, a2, false, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: false,
            margin: 1e7,
            amount: 2e20
        }));
        assertLiquidatePrice(btcPoolId, a2, false, false, 2021502e7);
        vm.assertFalse(false);

        vm.warp(block.timestamp + 4 days + 1);
        setPrice(ethId, 2022e8);
        pools.updateFunding(btcPoolId);
        assertLiquidatePrice(btcPoolId, a2, false, true, 2007016e7);

        
        setPrice(ethId, 2025e8);

        vm.expectRevert(IInsuranceManager.InsufficientBalance.selector);
        markets.liquidate(btcPoolId, a2, address(this), false);

        vm.startPrank(a2);
        btc.approve(address(im), 1e18);
        im.donate(btcPoolId, 2e7);
        vm.stopPrank();
        IMarkets.Position memory p = markets.getPositionInfo(btcPoolId, a2, false);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceUsed(btcPoolId, 1589605);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(btcPoolId, a2, false, address(this), p.margin, p.amount, p.value, 0, -851933280000000000, 0, 291168000000000000);
        (int256 marginBalance, , ) = markets.liquidate(btcPoolId, a2, address(this), false);
        vm.assertEq(marginBalance, 0, "MBE");
        vm.assertEq(im.userBalances(address(this), address(btc)), 100000, "UBE");
        vm.assertEq(im.poolBalances(btcPoolId), 2e7-1589605, "PBE");
        assertTakerPosition(btcPoolId, a2, false, 0, 0, 0, 0, 0);
        vm.assertEq(btc.balanceOf(a2), 3e7, "A2B");
        vm.assertEq(pools.unsettledFundingPayment(btcPoolId), 0);
    }

    // test liquidate taker long position 0
    function testLiquidateBtcPoolTL0() public {
        btc.approve(address(markets), 1e18);

        assertLiquidatePrice(btcPoolId, a2, true, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: true,
            margin: 3e7,
            amount: 4e20
        }));
        assertLiquidatePrice(btcPoolId, a2, true, false, 1975030e7);

        vm.warp(block.timestamp + 3 days + 1);
        setPrice(ethId, 1975e8);
        assertLiquidatePrice(btcPoolId, a2, true, true, 2012545e7);

        setPrice(ethId, 2010e8);
        vm.expectRevert(IMarkets.PositionDanger.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: true,
            margin: 1e7,
            amount: 1e20
        }));

        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: true,
            margin: 5e7,
            amount: 1e20
        }));
        assertTakerPosition(btcPoolId, a2, true, 5e20, 102663525e16, 795893459e10, 37989000000000000000, 151956e13);
        assertLiquidatePrice(btcPoolId, a2, true, false, 1934153e7);

        vm.warp(block.timestamp + 1 days + 1);
        setPrice(ethId, 1950e8);
        assertLiquidatePrice(btcPoolId, a2, true, true, 1953849e7);
        assertTakerPosition(btcPoolId, a2, true, 5e20, 102663525e16, 795893459e10, 37989000000000000000, 151956e13);
        

        vm.startPrank(a2);
        vm.expectRevert(IMarkets.InvalidCall.selector);
        markets.liquidate(btcPoolId, a2, address(this), true);
        vm.stopPrank();

        
        uint256 balance0 = btc.balanceOf(address(this));
        IMarkets.Position memory p = markets.getPositionInfo(btcPoolId, a2, true);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceAdded(btcPoolId, 1283294);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(btcPoolId, a2, true, address(this), p.margin, p.amount, p.value, 39e15, -5163525e12, 2566588125e8, 2499435e12);
        (int256 marginBalance, , ) = markets.liquidate(btcPoolId, a2, address(this), true);
        vm.assertEq(marginBalance, 3157, "MBE");
        vm.assertEq(im.userBalances(address(this), address(btc)), 100000, "UBE");
        vm.assertEq(im.poolBalances(btcPoolId), 1283294, "PBE");
        assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
        // fund to plugin[this]
        vm.assertEq(btc.balanceOf(a2), 0, "A2B");
        vm.assertEq(btc.balanceOf(address(this)), balance0+1283294+3157, "IMB");

        vm.assertEq(pools.unsettledFundingPayment(btcPoolId), 0);
    }

    // test liquidate taker long position 1
    function testLiquidateBtcPoolTL1() public {
        btc.approve(address(markets), 1e18);

        assertLiquidatePrice(btcPoolId, a2, true, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: true,
            margin: 3e7,
            amount: 4e20
        }));
        assertLiquidatePrice(btcPoolId, a2, true, false, 1975030e7);

        vm.warp(block.timestamp + 3 days + 1);
        setPrice(ethId, 1975e8);
        assertLiquidatePrice(btcPoolId, a2, true, true, 2012545e7);

        markets.addMargin(btcPoolId, a2, true, 2e7);
        assertLiquidatePrice(btcPoolId, a2, true, false, 1962294e7);
        

        vm.startPrank(a2);
        vm.expectRevert(IMarkets.InvalidCall.selector);
        markets.liquidate(btcPoolId, a2, address(this), true);
        vm.stopPrank();

        setPrice(ethId, 1955e8);
        uint256 balance0 = btc.balanceOf(address(this));
        IMarkets.Position memory p = markets.getPositionInfo(btcPoolId, a2, true);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceAdded(btcPoolId, 845105);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(btcPoolId, a2, true, address(this), p.margin, p.amount, p.value, 3128e13, -33736e14, 84510560000000000, 147798e13);
        (int256 marginBalance, , ) = markets.liquidate(btcPoolId, a2, address(this), true);
        vm.assertEq(marginBalance, 0, "MBE");
        vm.assertEq(im.userBalances(address(this), address(btc)), 100000, "UBE");
        vm.assertEq(im.poolBalances(btcPoolId), 845105, "PBE");
        assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
        vm.assertEq(btc.balanceOf(a2), 0, "A2B");
        vm.assertEq(btc.balanceOf(address(this)), balance0, "IMB");
        vm.assertEq(pools.unsettledFundingPayment(btcPoolId), 0);
    }

    // test liquidate taker long position 2
    function testLiquidateBtcPoolTL2() public {
        btc.approve(address(markets), 1e18);

        assertLiquidatePrice(btcPoolId, a2, true, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: true,
            margin: 2e7,
            amount: 3e20
        }));
        assertLiquidatePrice(btcPoolId, a2, true, false, 1972278e7);

        
        setPrice(ethId, 1950e8);
        vm.startPrank(a2);
        vm.expectRevert(IMarkets.InvalidCall.selector);
        markets.liquidate(btcPoolId, a2, address(this), true);
        vm.stopPrank();

        btc.approve(address(im), 1e18);
        im.donate(btcPoolId, 3e7);
        uint256 balance0 = btc.balanceOf(address(this));
        IMarkets.Position memory p = markets.getPositionInfo(btcPoolId, a2, true);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceUsed(btcPoolId, 3725225);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(btcPoolId, a2, true, address(this), p.margin, p.amount, p.value, 0, -234818324e10, 0, 0);
        (int256 marginBalance, , ) = markets.liquidate(btcPoolId, a2, address(this), true);
        vm.assertEq(marginBalance, 0, "MBE");
        vm.assertEq(im.userBalances(address(this), address(btc)), 1e5, "UBE");
        vm.assertEq(im.poolBalances(btcPoolId), 3e7-3725225, "PBE");
        assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
        vm.assertEq(btc.balanceOf(a2), 0, "A2B");
        vm.assertEq(btc.balanceOf(address(this)), balance0+0, "IMB");
    }

    // test liquidate maker position 0 
    function testLiquidateBtcPoolMP0() public {
        int256 marginBalance;
        btc.approve(address(markets), 1e18);
        assertBrokePrice(btcPoolId, address(this), false, false);
        vm.warp(block.timestamp+31 days);
        setPrice(ethId, 1000066e8);
        pools.removeLiquidity(btcPoolId, address(this), 500000e20, address(this));
        assertBrokePrice(btcPoolId, address(this), false, false);

        
        setPrice(ethId, 2000e8);
        pools.addLiquidity(btcPoolId, l1, 2e9, 4e20);
        pools.addLiquidity(btcPoolId, l2, 2e9, 40e20);
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, false, false);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: t1,
            direction: true,
            margin: 1e9,
            amount: 50e20
        }));
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, false, false);


        setPrice(ethId, 2420e8);
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, true, false);

        vm.expectRevert(IPools.NotLiquidate.selector);
        pools.liquidate(btcPoolId, l1, address(this));

        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l2, btcPoolId, 40e20, 40e20, 2e20, 9546413807, -181434477200000000000, 10000000000000000000);
        (marginBalance, ) = pools.liquidate(btcPoolId, l2, address(this));
        vm.assertEq(im.userBalances(address(this), address(btc)), 1e5);
        vm.assertEq(marginBalance, 85655228);
        assertGlobalPosition(btcPoolId, 4e20, 4e20+1814344772e11+202044006272000000, 2e20+1814344772e11+202044006272000000);


        assertBrokePrice(btcPoolId, l1, false, false);

        vm.expectRevert(IPools.NotBroke.selector);
        pools.broke(btcPoolId);
        vm.expectRevert(IPools.NotLiquidate.selector);
        pools.liquidate(btcPoolId, l1, address(this));

        setPrice(ethId, 2782e8);
        assertBrokePrice(btcPoolId, l1, true, true);
        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l1, btcPoolId, 4e20, 4e20, 2e20, 5021413814, -199143447440000000000, 856552560000000000);
        (marginBalance, ) = pools.liquidate(btcPoolId, l1, address(this));
        vm.assertEq(im.userBalances(address(this), address(btc)), 2e5);
        vm.assertEq(marginBalance, 0);


        vm.expectRevert(IMarkets.NotLiquidate.selector);
        markets.liquidate(btcPoolId, t1, address(this), true);

        vm.startPrank(t1);
        markets.decreasePosition(btcPoolId, t1, true, 1e20);
        vm.stopPrank();

        vm.expectRevert(IPools.InsufficientLiquidity.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: t1,
            direction: true,
            margin: 1e7,
            amount: 1e20
        }));
    }

    // test liquidate maker position 1 
    function testLiquidateBtcPoolMP1() public {
        int256 marginBalance;
        btc.approve(address(markets), 1e18);
        assertBrokePrice(btcPoolId, address(this), false, false);
        vm.warp(block.timestamp+31 days);
        setPrice(ethId, 1000066e8);
        pools.removeLiquidity(btcPoolId, address(this), 500000e20, address(this));
        assertBrokePrice(btcPoolId, address(this), false, false);

        
        setPrice(ethId, 2000e8);
        pools.addLiquidity(btcPoolId, l1, 2e9, 4e20);
        pools.addLiquidity(btcPoolId, l2, 2e9, 40e20);
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, false, false);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: t1,
            direction: true,
            margin: 1e9,
            amount: 50e20
        }));
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, false, false);


        setPrice(ethId, 2420e8);
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, true, false);

        vm.expectRevert(IPools.NotLiquidate.selector);
        pools.liquidate(btcPoolId, l1, address(this));

        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(l1, l2, btcPoolId, 40e20, 40e20, 2e20, 9546413807, -181434477200000000000, 10000000000000000000);
        (marginBalance, ) = pools.liquidate(btcPoolId, l2, l1);
        vm.assertEq(im.userBalances(l1, address(btc)), 1e5);
        vm.assertEq(marginBalance, 85655228);
        assertGlobalPosition(btcPoolId, 4e20, 4e20+1814344772e11+202044006272000000, 2e20+1814344772e11+202044006272000000);


        assertBrokePrice(btcPoolId, l1, false, false);

        vm.expectRevert(IPools.NotBroke.selector);
        pools.broke(btcPoolId);
        vm.expectRevert(IPools.NotLiquidate.selector);
        pools.liquidate(btcPoolId, l1, address(this));

        setPrice(ethId, 2782e8);
        assertBrokePrice(btcPoolId, l1, true, true);

        pools.broke(btcPoolId);
        vm.assertEq(im.userBalances(address(this), address(btc)), 10e5);

        vm.expectRevert(IPools.Broked.selector);
        vm.startPrank(t1);
        markets.decreasePosition(btcPoolId, t1, true, 100e20);
        vm.stopPrank();

        markets.liquidate(btcPoolId, t1, address(this), true);

        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l1, btcPoolId, 4e20, 4e20, 2e20, 5021413814, -199143447440000000000, 856552560000000000);
        (marginBalance, ) = pools.liquidate(btcPoolId, l1, address(this));
        vm.assertEq(im.userBalances(address(this), address(btc)), 12e5);
        vm.assertEq(marginBalance, 0);
        

        vm.expectRevert(IPools.Broked.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: t1,
            direction: true,
            margin: 1e7,
            amount: 1e20
        }));

        pools.restorePool(btcPoolId);
        vm.assertEq(im.userBalances(address(this), address(btc)), 22e5);

        pools.addLiquidity(btcPoolId, l1, 2e9, 4e20);
    }

    // test liquidate maker position 2 
    function testLiquidateBtcPoolMP2() public {
        int256 marginBalance;
        btc.approve(address(markets), 1e18);
        btc.approve(address(im), 1e18);
        assertBrokePrice(btcPoolId, address(this), false, false);
        vm.warp(block.timestamp+31 days);
        setPrice(ethId, 1000066e8);
        pools.removeLiquidity(btcPoolId, address(this), 500000e20, address(this));
        assertBrokePrice(btcPoolId, address(this), false, false);

        
        setPrice(ethId, 2000e8);
        pools.addLiquidity(btcPoolId, l1, 2e9, 4e20);
        pools.addLiquidity(btcPoolId, l2, 2e9, 40e20);
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, false, false);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: t1,
            direction: true,
            margin: 1e9,
            amount: 50e20
        }));
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, false, false);


        setPrice(ethId, 2420e8);
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, true, false);

        vm.expectRevert(IPools.NotLiquidate.selector);
        pools.liquidate(btcPoolId, l1, address(this));

        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l2, btcPoolId, 40e20, 40e20, 2e20, 9546413807, -181434477200000000000, 10000000000000000000);
        (marginBalance, ) = pools.liquidate(btcPoolId, l2, address(this));
        vm.assertEq(im.userBalances(address(this), address(btc)), 1e5);
        vm.assertEq(marginBalance, 85655228);
        assertGlobalPosition(btcPoolId, 4e20, 4e20+1814344772e11+202044006272000000, 2e20+1814344772e11+202044006272000000);


        assertBrokePrice(btcPoolId, l1, false, false);

        vm.expectRevert(IPools.NotBroke.selector);
        pools.broke(btcPoolId);
        vm.expectRevert(IPools.NotLiquidate.selector);
        pools.liquidate(btcPoolId, l1, address(this));

        setPrice(ethId, 2800e8);
        assertBrokePrice(btcPoolId, l1, true, true);

        pools.broke(btcPoolId);
        vm.assertEq(im.userBalances(address(this), address(btc)), 11e5);

        vm.expectRevert(IPools.Broked.selector);
        vm.startPrank(t1);
        markets.decreasePosition(btcPoolId, t1, true, 100e20);
        vm.stopPrank();

        // vm.expectRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        vm.expectRevert();
        markets.liquidate(btcPoolId, t1, address(this), true);


        im.donate(btcPoolId, 1e9);

        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l1, btcPoolId, 4e20, 4e20, 2e20, 4796413814, -208143447440000000000, 0);
        (marginBalance, ) = pools.liquidate(btcPoolId, l1, address(this));
        vm.assertEq(im.userBalances(address(this), address(btc)), 12e5);
        vm.assertEq(im.poolBalances(btcPoolId), 1e9+50000000-81434474);
        vm.assertEq(marginBalance, 0);

        markets.liquidate(btcPoolId, t1, address(this), true);
        

        vm.expectRevert(IPools.Broked.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: t1,
            direction: true,
            margin: 1e7,
            amount: 1e20
        }));

        pools.restorePool(btcPoolId);
        vm.assertEq(im.userBalances(address(this), address(btc)), 23e5);

        pools.addLiquidity(btcPoolId, l1, 2e9, 4e20);
    }

    // test liquidate maker position 3 
    function testLiquidateBtcPoolMP3() public {
        int256 marginBalance;
        btc.approve(address(markets), 1e18);
        btc.approve(address(im), 1e18);
        assertBrokePrice(btcPoolId, address(this), false, false);
        vm.warp(block.timestamp+31 days);
        setPrice(ethId, 130066e8);
        pools.removeLiquidity(btcPoolId, address(this), 500000e20, address(this));
        assertBrokePrice(btcPoolId, address(this), false, false);

        
        setPrice(ethId, 2000e8);
        pools.addLiquidity(btcPoolId, l1, 2e9, 30e20);
        pools.addLiquidity(btcPoolId, l2, 2e9, 40e20);
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, false, false);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: t1,
            direction: false,
            margin: 2e9,
            amount: 50e20
        }));
        assertBrokePrice(btcPoolId, l1, false, false);
        assertBrokePrice(btcPoolId, l2, false, false);


        setPrice(ethId, 1200e8);
        assertBrokePrice(btcPoolId, l1, true, true);
        assertBrokePrice(btcPoolId, l2, true, true);

        pools.broke(btcPoolId);
        vm.assertEq(im.userBalances(address(this), address(btc)), 10e5);

        im.donate(btcPoolId, 1e9);
        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l2, btcPoolId, 40e20, 40e20, 2e20, 9437396654, -2250413384e11, 0);
        (marginBalance, ) = pools.liquidate(btcPoolId, l2, address(this));
        vm.assertEq(im.userBalances(address(this), address(btc)), 11e5);
        vm.assertEq(marginBalance, 0);
        assertGlobalPosition(btcPoolId, 30e20, 70e20-9437396654*40e20/1e10+198804229200000000, 2e20+2250413384e11+198804229200000000);

        markets.liquidate(btcPoolId, t1, address(this), false);
        assertGlobalPosition(btcPoolId, 30e20, 32252401426292e8+12e16-394021146e12, 425240142629200000000+12e16-394021146e12);
        

        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l1, btcPoolId, 30e20, 30e20, 2e20, 9437396654, -1687810038e11, 75e17);
        (marginBalance, ) = pools.liquidate(btcPoolId, l1, address(this));
        vm.assertEq(im.userBalances(address(this), address(btc)), 13e5);
        vm.assertEq(marginBalance, 237189962);
        assertGlobalPosition(btcPoolId, 0, 2831338996629200000000-9437396654*30e20/1e10, 31338996629200000000-2e20+168781003800000000000);

        pools.restorePool(btcPoolId);
        vm.assertEq(im.userBalances(address(this), address(btc)), 23e5);
    }

    function assertPosition(bytes32 poolId, address maker, int256 amount, int256 value, int256 margin, uint256 increaseTime) private view {
        IPools.Position memory pos = pools.getPosition(poolId, maker);
        vm.assertEq(pos.amount, amount, "MPA");
        vm.assertEq(pos.margin, margin, "MPM");
        vm.assertEq(pos.value, value, "MPV");
        vm.assertEq(pos.increaseTime, increaseTime, "MPT");
    }

    function assertGlobalPosition(bytes32 poolId, int256 amount, int256 value, int256 margin) private view {
        (int256 gAmount, int256 gValue, int256 gMargin) = pools.globalPosition(poolId);
        vm.assertGe(gAmount, amount, "GPAG");
        vm.assertLt(gAmount, amount+1e10, "GPAL");
        vm.assertGe(gValue, value, "GPVG");
        vm.assertLt(gValue, value+1e10, "GPVL");
        vm.assertGe(gMargin, margin, "GPMG");
        vm.assertLt(gMargin, margin+1e10, "GPML");
    }

    function assertPoolStatus(bytes32 poolId, bool direction, int256 amount, int256 value, int256 margin) private view {
        (int256 pAmount, int256 pValue, int256 pMargin) = pools.poolStatus(poolId, direction?1:0);
        vm.assertGe(pAmount, amount, "PAG");
        vm.assertLe(pAmount, amount+1e10, "PAL");
        vm.assertGe(pValue, value, "PVG");
        vm.assertLe(pValue, value+1e10, "PVL");
        vm.assertGe(pMargin, margin, "PMG");
        vm.assertLe(pMargin, margin+1e10, "PML");
    }

    function assertFundInfo(bytes32 poolId, int256 makerFund, int256 limitFund, int256 availableFund) private view {
        (int256 mFund, int256 lFund, int256 aFund) = pools.getFundInfo(poolId);
        vm.assertGe(mFund, makerFund, "MFG");
        vm.assertLt(mFund, makerFund+1e10, "MFL");
        vm.assertGe(lFund, limitFund, "LFG");
        vm.assertLt(lFund, limitFund+1e10, "LFL");
        vm.assertGe(aFund, availableFund, "AFG");
        vm.assertLt(aFund, availableFund+1e10, "AFL");
    }

    function assertTakerPosition(bytes32 marketId, address taker, bool direction, int256 amount, int256 value, int256 margin, int256 fg, int256 ufp) private view {
        IMarkets.Position memory pos = markets.getPositionInfo(marketId, taker, direction);
        vm.assertGe(pos.amount, amount, "TPAG");
        vm.assertLt(pos.amount, amount+1e10, "TPAL");
        vm.assertGe(pos.margin, margin, "TPMG");
        vm.assertLt(pos.margin, margin+1e10, "TPMG");
        vm.assertGe(pos.value, value, "TPVG");
        vm.assertLt(pos.value, value+1e10, "TPVL");
        vm.assertGe(pos.fundingGrowthGlobal, fg, "TPFG");
        vm.assertLt(pos.fundingGrowthGlobal, fg+100, "TPFL");
        vm.assertGe(pos.unsettledFundingPayment, ufp, "TPUG");
        vm.assertLt(pos.unsettledFundingPayment, ufp+100, "TPUL");
    }

    function assertTickStatus(bytes32 poolId, int256 makerAmount, int256 position) public view {
        IMatchingEngine.TickStatus memory s = me.getStatus(poolId);
        vm.assertGe(s.makerAmount, makerAmount, "TSAG");
        vm.assertLt(s.makerAmount, makerAmount+1e18, "TSAL");
        vm.assertGe(s.position, position, "TSPG");
        vm.assertLt(s.position, position+1e18, "TSPL");
    }

    function assertMarketPrice(bytes32 poolId, int256 price) public view {
        int256 p = pools.getMarketPrice(poolId, 0);
        vm.assertGe(p, price, "MPG");
        vm.assertLt(p, price+1e8, "MPL");
    }

    function assertLiquidatePrice(bytes32 poolId, address taker, bool direction, bool lqd, int256 price) public view {
        (bool liquidated, int256 lp) = markets.isLiquidatable(poolId, taker, direction);
        vm.assertEq(liquidated, lqd, "LQD");
        vm.assertGe(lp, price, "LPG");
        vm.assertLt(lp, price+1e8, "LPL");
    }

    function assertBrokePrice(bytes32 poolId, address maker, bool liquidated, bool broked) public view {
        (bool bd, ) = pools.isBroke(poolId);
        (bool ld, ) = pools.isLiquidatable(poolId, maker);
        vm.assertEq(bd, broked, "BKE");
        vm.assertEq(ld, liquidated, "LPE");
    }
}