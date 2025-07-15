// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./Init.sol";


/// test usd pool & markets 
contract LiquidateUSDTest is Init {
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

    // test liquidate taker long position 0
    function testLiquidateUsdPoolTL0() public {
        usd.approve(address(markets), 1e18);

        assertLiquidatePrice(usdPoolId, a2, true, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 100e6,
            amount: 1e18
        }));
        assertLiquidatePrice(usdPoolId, a2, true, false, 70402199e7);

        setPrice(btcId, 7040219e6);
        assertLiquidatePrice(usdPoolId, a2, true, true, 70402199e7);

        usd.mint(a2, 500e6);
        vm.startPrank(a2);
        usd.approve(address(markets), 1e18);
        markets.addMargin(usdPoolId, a2, true, 100e6);
        vm.stopPrank();
        assertLiquidatePrice(usdPoolId, a2, true, false, 60351948e7);
        assertPoolStatus(usdPoolId, true, 1e18, 800181816e14, 19967992727360000000000);

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
        (int256 marginBalance, , ) = markets.liquidate(usdPoolId, a2, address(this), true);
        vm.assertEq(marginBalance, 256456, "MBE");
        vm.assertEq(im.userBalances(address(this), address(usd)), 5e6, "UBE");
        vm.assertEq(im.poolBalances(usdPoolId), 1000227, "PBE");
        assertTakerPosition(usdPoolId, a2, true, 0, 0, 0, 0, 0);
        // fund to plugin[this]
        vm.assertEq(usd.balanceOf(a2), 400e6, "A2B");
        vm.assertEq(usd.balanceOf(address(this)), balance0+1000227+256456, "IMB");
    }

    // test liquidate taker long position 1
    function testLiquidateUsdPoolTL1() public {
        usd.approve(address(markets), 1e18);

        assertLiquidatePrice(usdPoolId, a2, true, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 100e6,
            amount: 1e18
        }));
        assertLiquidatePrice(usdPoolId, a2, true, false, 70402199e7);

        usd.mint(a2, 500e6);
        vm.startPrank(a2);
        usd.approve(address(markets), 1e18);
        markets.addMargin(usdPoolId, a2, true, 100e6);
        vm.stopPrank();
        assertLiquidatePrice(usdPoolId, a2, true, false, 60351948e7);
        assertPoolStatus(usdPoolId, true, 1e18, 800181816e14, 19967992727360000000000);


        vm.startPrank(a2);
        vm.expectRevert(IMarkets.InvalidCall.selector);
        markets.liquidate(usdPoolId, a2, address(this), true);
        vm.stopPrank();
        vm.expectRevert(IMarkets.NotLiquidate.selector);
        markets.liquidate(usdPoolId, a2, address(this), true);

        setPrice(btcId, 6025000e6);

        IMarkets.Position memory p = markets.getPositionInfo(usdPoolId, a2, true);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceAdded(usdPoolId, 1000227);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(usdPoolId, a2, true, address(this), p.margin, p.amount, p.value, 2410e16, -197681816e14, 17571112736e10, 0);
        (int256 marginBalance, , ) = markets.liquidate(usdPoolId, a2, address(this), true);
        vm.assertEq(marginBalance, 0, "MBE");
        vm.assertEq(im.userBalances(address(this), address(usd)), 5e6, "UBE");
        vm.assertEq(im.poolBalances(usdPoolId), 1000227, "PBE");
        assertTakerPosition(usdPoolId, a2, true, 0, 0, 0, 0, 0);
        vm.assertEq(usd.balanceOf(a2), 400e6, "A2B");
    }

    // test liquidate taker long position 2
    function testLiquidateUsdPoolTL2() public {
        usd.approve(address(markets), 1e18);
        usd.mint(a2, 500e6);

        assertLiquidatePrice(usdPoolId, a2, true, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 150e6,
            amount: 2e18
        }));
        assertLiquidatePrice(usdPoolId, a2, true, false, 72934894e7);

        vm.warp(block.timestamp + 4 days + 1);
        setPrice(btcId, 73500e8);
        pools.updateFunding(usdPoolId);
        assertLiquidatePrice(usdPoolId, a2, true, false, 73023537e7);

        
        setPrice(btcId, 72500e8);

        vm.expectRevert(IInsuranceManager.InsufficientBalance.selector);
        markets.liquidate(usdPoolId, a2, address(this), true);

        vm.startPrank(a2);
        usd.approve(address(im), 1e18);
        im.donate(usdPoolId, 200e6);
        vm.stopPrank();
        IMarkets.Position memory p = markets.getPositionInfo(usdPoolId, a2, true);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceUsed(usdPoolId, 3168395);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(usdPoolId, a2, true, address(this), p.margin, p.amount, p.value, 0, -15076408960000000000000, 0, 176400000000000000000);
        (int256 marginBalance, , ) = markets.liquidate(usdPoolId, a2, address(this), true);
        vm.assertEq(marginBalance, 0, "MBE");
        vm.assertEq(im.userBalances(address(this), address(usd)), 5e6, "UBE");
        vm.assertEq(im.poolBalances(usdPoolId), 200e6-3168395, "PBE");
        assertTakerPosition(usdPoolId, a2, true, 0, 0, 0, 0, 0);
        vm.assertEq(usd.balanceOf(a2), 300e6, "A2B");
        vm.assertEq(pools.unsettledFundingPayment(usdPoolId), 0);
    }

    // test liquidate taker short position 0
    function testLiquidateUsdPoolTS0() public {
        usd.approve(address(markets), 1e18);

        assertLiquidatePrice(usdPoolId, a2, false, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: false,
            margin: 1000e6,
            amount: 3e19
        }));
        assertLiquidatePrice(usdPoolId, a2, false, false, 82111708e7);

        vm.warp(block.timestamp + 3 days + 1);
        setPrice(btcId, 8211171e6);
        assertLiquidatePrice(usdPoolId, a2, false, true, 81614810e7);


        setPrice(btcId, 8130000e6);
        vm.expectRevert(IMarkets.PositionDanger.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: false,
            margin: 100e6,
            amount: 1e19
        }));

        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: false,
            margin: 500e6,
            amount: 1e19
        }));
        assertTakerPosition(usdPoolId, a2, false, -4e19, 3169022679640000000000000, 148732390928144000000000, -494446275000000000000, 14833388250000000000000);
        assertLiquidatePrice(usdPoolId, a2, false, false, 82162230e7);

        vm.warp(block.timestamp + 1 days + 1);
        setPrice(btcId, 8200000e6);
        assertLiquidatePrice(usdPoolId, a2, false, true, 81922648e7);
        assertTakerPosition(usdPoolId, a2, false, -4e19, 3169022679640000000000000, 148732390928144000000000, -494446275000000000000, 14833388250000000000000);
        

        vm.startPrank(a2);
        vm.expectRevert(IMarkets.InvalidCall.selector);
        markets.liquidate(usdPoolId, a2, address(this), false);
        vm.stopPrank();

        
        uint256 balance0 = usd.balanceOf(address(this));
        IMarkets.Position memory p = markets.getPositionInfo(usdPoolId, a2, false);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceAdded(usdPoolId, 39612783);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(usdPoolId, a2, false, address(this), p.margin, p.amount, p.value, 1312e18, -11097732036e13, 79225566991e11, 2446458345e13);
        (int256 marginBalance, , ) = markets.liquidate(usdPoolId, a2, address(this), false);
        vm.assertEq(marginBalance, 40559304, "MBE");
        vm.assertEq(im.userBalances(address(this), address(usd)), 5e6, "UBE");
        vm.assertEq(im.poolBalances(usdPoolId), 39612783, "PBE");
        assertTakerPosition(usdPoolId, a2, false, 0, 0, 0, 0, 0);
        // fund to plugin[this]
        vm.assertEq(usd.balanceOf(a2), 0, "A2B");
        vm.assertEq(usd.balanceOf(address(this)), balance0+39612783+40559304, "IMB");

        vm.assertEq(pools.unsettledFundingPayment(usdPoolId), 0);
    }

    // test liquidate taker short position 1
    function testLiquidateUsdPoolTS1() public {
        usd.approve(address(markets), 1e18);

        assertLiquidatePrice(usdPoolId, a2, false, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: false,
            margin: 1000e6,
            amount: 3e19
        }));
        assertLiquidatePrice(usdPoolId, a2, false, false, 82111708e7);

        vm.warp(block.timestamp + 3 days + 1);
        setPrice(btcId, 8211171e6);
        assertLiquidatePrice(usdPoolId, a2, false, true, 81614810e7);

        markets.addMargin(usdPoolId, a2, false, 200e6);
        assertLiquidatePrice(usdPoolId, a2, false, false, 82278160e7);
        

        vm.startPrank(a2);
        vm.expectRevert(IMarkets.InvalidCall.selector);
        markets.liquidate(usdPoolId, a2, address(this), false);
        vm.stopPrank();

        setPrice(btcId, 8250000e6);
        uint256 balance0 = usd.balanceOf(address(this));
        IMarkets.Position memory p = markets.getPositionInfo(usdPoolId, a2, false);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceAdded(usdPoolId, 29707733);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(usdPoolId, a2, false, address(this), p.margin, p.amount, p.value, 99e19, -983813312e14, 462569008248e10, 1505233125e13);
        (int256 marginBalance, , ) = markets.liquidate(usdPoolId, a2, address(this), false);
        vm.assertEq(marginBalance, 0, "MBE");
        vm.assertEq(im.userBalances(address(this), address(usd)), 5e6, "UBE");
        vm.assertEq(im.poolBalances(usdPoolId), 29707733, "PBE");
        assertTakerPosition(usdPoolId, a2, false, 0, 0, 0, 0, 0);
        vm.assertEq(usd.balanceOf(a2), 0, "A2B");
        vm.assertEq(usd.balanceOf(address(this)), balance0+16549167, "IMB");
        vm.assertEq(pools.unsettledFundingPayment(usdPoolId), 0);
    }

    // test liquidate taker short position 2
    function testLiquidateUsdPoolTS2() public {
        usd.approve(address(markets), 1e18);

        assertLiquidatePrice(usdPoolId, a2, false, false, 0);
        
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: false,
            margin: 2000e6,
            amount: 5e19
        }));
        assertLiquidatePrice(usdPoolId, a2, false, false, 82146207e7);

        
        setPrice(btcId, 83000e8);
        vm.startPrank(a2);
        vm.expectRevert(IMarkets.InvalidCall.selector);
        markets.liquidate(usdPoolId, a2, address(this), false);
        vm.stopPrank();

        usd.approve(address(im), 1e18);
        im.donate(usdPoolId, 300e6);
        uint256 balance0 = usd.balanceOf(address(this));
        IMarkets.Position memory p = markets.getPositionInfo(usdPoolId, a2, false);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceUsed(usdPoolId, 221530858);
        vm.expectEmit(address(markets));
        emit IMarkets.LiquidatedPosition(usdPoolId, a2, false, address(this), p.margin, p.amount, p.value, 0, -2205813184e14, 0, 0);
        (int256 marginBalance, , ) = markets.liquidate(usdPoolId, a2, address(this), false);
        vm.assertEq(marginBalance, 0, "MBE");
        vm.assertEq(im.userBalances(address(this), address(usd)), 5e6, "UBE");
        vm.assertEq(im.poolBalances(usdPoolId), 300e6-221530858, "PBE");
        assertTakerPosition(usdPoolId, a2, false, 0, 0, 0, 0, 0);
        vm.assertEq(usd.balanceOf(a2), 0, "A2B");
        vm.assertEq(usd.balanceOf(address(this)), balance0+0, "IMB");
    }

    // test liquidate maker position 0 
    function testLiquidateUsdPoolMP0() public {
        int256 marginBalance;
        usd.approve(address(markets), 1e18);
        assertBrokePrice(usdPoolId, address(this), false, false);
        vm.warp(block.timestamp+31 days);
        setPrice(btcId, 130066e8);
        pools.removeLiquidity(usdPoolId, address(this), 500000e20, address(this));
        assertBrokePrice(usdPoolId, address(this), false, false);

        
        pools.addLiquidity(usdPoolId, l1, 20000e6, 40000e20);
        pools.addLiquidity(usdPoolId, l2, 20000e6, 400000e20);
        assertBrokePrice(usdPoolId, l1, false, false);
        assertBrokePrice(usdPoolId, l2, false, false);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: t1,
            direction: false,
            margin: 10000e6,
            amount: 1e20
        }));
        assertBrokePrice(usdPoolId, l1, false, false);
        assertBrokePrice(usdPoolId, l2, false, false);


        setPrice(btcId, 108000e8);
        assertBrokePrice(usdPoolId, l1, false, false);
        assertBrokePrice(usdPoolId, l2, true, false);

        vm.expectRevert(IPools.NotLiquidate.selector);
        pools.liquidate(usdPoolId, l1, address(this));

        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l2, usdPoolId, 400000e20, 400000e20, 20000e20, 9540160783, -1839356868000000000000000, 1000e20);
        (marginBalance, ) = pools.liquidate(usdPoolId, l2, address(this));
        vm.assertEq(im.userBalances(address(this), address(usd)), 5e6);
        vm.assertEq(marginBalance, 606431320);

        assertBrokePrice(usdPoolId, l1, false, false);

        vm.expectRevert(IPools.NotBroke.selector);
        pools.broke(usdPoolId);
        vm.expectRevert(IPools.NotLiquidate.selector);
        pools.liquidate(usdPoolId, l1, address(this));

        setPrice(btcId, 89900e8);
        assertBrokePrice(usdPoolId, l1, true, true);
        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l1, usdPoolId, 40000e20, 40000e20, 20000e20, 5015160786, -19939356856e14, 60643144e14);
        (marginBalance, ) = pools.liquidate(usdPoolId, l1, address(this));
        vm.assertEq(im.userBalances(address(this), address(usd)), 10e6);
        vm.assertEq(marginBalance, 0);


        vm.expectRevert(IMarkets.NotLiquidate.selector);
        markets.liquidate(usdPoolId, t1, address(this), false);

        vm.startPrank(t1);
        markets.decreasePosition(usdPoolId, t1, false, 1e20);
        vm.stopPrank();

        vm.expectRevert(IPools.InsufficientLiquidity.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: t1,
            direction: false,
            margin: 100e6,
            amount: 1e18
        }));
    }

    // test liquidate maker position 1 
    function testLiquidateUsdPoolMP1() public {
        int256 marginBalance;
        usd.approve(address(markets), 1e18);
        assertBrokePrice(usdPoolId, address(this), false, false);
        vm.warp(block.timestamp+31 days);
        setPrice(btcId, 130066e8);
        pools.removeLiquidity(usdPoolId, address(this), 500000e20, address(this));
        assertBrokePrice(usdPoolId, address(this), false, false);

        
        pools.addLiquidity(usdPoolId, l1, 20000e6, 40000e20);
        pools.addLiquidity(usdPoolId, l2, 20000e6, 400000e20);
        assertBrokePrice(usdPoolId, l1, false, false);
        assertBrokePrice(usdPoolId, l2, false, false);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: t1,
            direction: false,
            margin: 10000e6,
            amount: 1e20
        }));
        assertBrokePrice(usdPoolId, l1, false, false);
        assertBrokePrice(usdPoolId, l2, false, false);


        setPrice(btcId, 108000e8);
        assertBrokePrice(usdPoolId, l1, false, false);
        assertBrokePrice(usdPoolId, l2, true, false);

        vm.expectRevert(IPools.NotLiquidate.selector);
        pools.liquidate(usdPoolId, l1, address(this));

        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l2, usdPoolId, 400000e20, 400000e20, 20000e20, 9540160783, -1839356868000000000000000, 1000e20);
        (marginBalance, ) = pools.liquidate(usdPoolId, l2, address(this));
        vm.assertEq(im.userBalances(address(this), address(usd)), 5e6);
        vm.assertEq(marginBalance, 606431320);

        assertBrokePrice(usdPoolId, l1, false, false);

        vm.expectRevert(IPools.NotBroke.selector);
        pools.broke(usdPoolId);
        vm.expectRevert(IPools.NotLiquidate.selector);
        pools.liquidate(usdPoolId, l1, address(this));

        setPrice(btcId, 89900e8);
        assertBrokePrice(usdPoolId, l1, true, true);

        pools.broke(usdPoolId);
        vm.assertEq(im.userBalances(address(this), address(usd)), 55e6);
        markets.liquidate(usdPoolId, t1, address(this), false);
        vm.assertEq(im.userBalances(address(this), address(usd)), 60e6);

        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l1, usdPoolId, 40000e20, 40000e20, 20000e20, 5015160786, -19939356856e14, 60643144e14);
        (marginBalance, ) = pools.liquidate(usdPoolId, l1, address(this));
        vm.assertEq(im.userBalances(address(this), address(usd)), 65e6);
        vm.assertEq(marginBalance, 0);


        pools.restorePool(usdPoolId);
        vm.assertEq(im.userBalances(address(this), address(usd)), 115e6);
        

        pools.addLiquidity(usdPoolId, l1, 20000e6, 40000e20);
    }

    // test liquidate maker position 2 
    function testLiquidateUsdPoolMP2() public {
        int256 marginBalance;
        usd.approve(address(markets), 1e18);
        usd.approve(address(im), 1e18);
        assertBrokePrice(usdPoolId, address(this), false, false);
        vm.warp(block.timestamp+31 days);
        setPrice(btcId, 130066e8);
        pools.removeLiquidity(usdPoolId, address(this), 500000e20, address(this));
        assertBrokePrice(usdPoolId, address(this), false, false);

        
        setPrice(btcId, 80000e8);
        pools.addLiquidity(usdPoolId, l1, 20000e6, 300000e20);
        pools.addLiquidity(usdPoolId, l2, 20000e6, 400000e20);
        assertBrokePrice(usdPoolId, l1, false, false);
        assertBrokePrice(usdPoolId, l2, false, false);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: t1,
            direction: true,
            margin: 10000e6,
            amount: 1e20
        }));
        assertBrokePrice(usdPoolId, l1, false, false);
        assertBrokePrice(usdPoolId, l2, false, false);


        setPrice(btcId, 117100e8);
        assertBrokePrice(usdPoolId, l1, true, true);
        assertBrokePrice(usdPoolId, l2, true, true);

        pools.broke(usdPoolId);
        vm.assertEq(im.userBalances(address(this), address(usd)), 50e6);

        im.donate(usdPoolId, 20000e6);
        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l2, usdPoolId, 400000e20, 400000e20, 20000e20, 9475525955, -209789618e16, 0);
        (marginBalance, ) = pools.liquidate(usdPoolId, l2, address(this));
        vm.assertEq(im.userBalances(address(this), address(usd)), 55e6);
        vm.assertEq(marginBalance, 0);
        assertGlobalPosition(usdPoolId, 300000e20, 700000e20-9475525955*400000e20/1e10+16074148544e11, 20000e20+209789618e16+16074148544e11);

        markets.liquidate(usdPoolId, t1, address(this), true);
        assertGlobalPosition(usdPoolId, 300000e20, 32099503594854400000000000+2342e18-3672925728e15, 4099503594854400000000000+2342e18-3672925728e15);
        

        vm.expectEmit(address(pools));
        emit IPools.LiquidatedLiquidity(address(this), l1, usdPoolId, 300000e20, 300000e20, 20000e20, 9475525955, -1573422135e15, 750e20);
        (marginBalance, ) = pools.liquidate(usdPoolId, l1, address(this));
        vm.assertEq(im.userBalances(address(this), address(usd)), 65e6);
        vm.assertEq(marginBalance, 3515778650);
        assertGlobalPosition(usdPoolId, 0, 28428919866854400000000000-9475525955*300000e20/1e10, 428919866854400000000000-20000e20+1573422135e15);

        pools.restorePool(usdPoolId);
        vm.assertEq(im.userBalances(address(this), address(usd)), 115e6);
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