// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./Init.sol";


/// test pool and markets 
contract TradeTest is Init {
    function setUp() public {
        initial();
    }
    
    function testPoolsConfig() public {
        vm.startPrank(a2);
        vm.expectRevert(Governable.notGov.selector);
        pools.setConfig(address(markets), address(cm), address(ph), address(me), address(im), address(eth), address(staker), 900);
        vm.stopPrank();
        vm.expectRevert(IPools.InvalidInterval.selector);
        pools.setConfig(address(markets), address(cm), address(ph), address(me), address(im), address(eth), address(staker), 599);
        vm.expectRevert(IPools.InvalidInterval.selector);
        pools.setConfig(address(markets), address(cm), address(ph), address(me), address(im), address(eth), address(staker), 28801);
        
        vm.expectEmit(address(pools));
        emit IPools.SetConfig(address(cm), address(ph), address(me), address(im), address(markets), address(eth), address(staker), 3600);
        pools.setConfig(address(cm), address(ph), address(me), address(im), address(markets), address(staker), address(eth), 3600);

        pools.setConfig(address(markets), address(cm), address(ph), address(me), address(im), address(eth), address(staker), 900);

        vm.expectRevert(IPools.PoolExisted.selector);
        pools.createPool(getPairId("BTC/USD"), address(usd), 110000e6, 1);
        vm.expectRevert(IPools.InvalidPair.selector);
        pools.createPool(getPairId("LTC/USD"), address(eth), 51e18, 1);
        vm.expectRevert(IPools.InvalidAsset.selector);
        pools.createPool(getPairId("BTC/USD"), a1, 51e18, 1);
        vm.expectRevert(IPools.InsufficientAmount.selector);
        pools.createPool(getPairId("BTC/USD"), address(eth), 3e18, 1);


        IPools.PoolConfig memory testConfig = IPools.PoolConfig({
            asset: address(btc),
            addPaused: true, 
            removePaused: true,
            liquidatePaused: true, 
            pairId: bytes32(0),
            precision: 0,
            imRatio: 3e6,
            mmRatio: 2e6,

            reserveRatio: 1e7,
            feeRatio: 1e4,
            multiplier: 1e8,
            makerLimit: 50000000e20,
            minimumMargin: 100e6,
            dust: 1e7
        });
        vm.expectRevert(Governable.notGov.selector);
        vm.startPrank(a2);
        pools.updatePoolConfig(btcId, testConfig);
        vm.stopPrank();
        vm.expectRevert(IPools.PoolNotExist.selector);
        pools.updatePoolConfig(btcId, testConfig);
        vm.expectRevert(IPools.InvalidReserveRatio.selector);
        testConfig.reserveRatio = 1e7-1;
        pools.updatePoolConfig(usdPoolId, testConfig);
        vm.expectRevert(IPools.InvalidReserveRatio.selector);
        testConfig.reserveRatio = 5e7+1;
        pools.updatePoolConfig(usdPoolId, testConfig);

        vm.expectRevert(IPools.InvalidIM.selector);
        testConfig.reserveRatio = 3e7;
        testConfig.imRatio = 1e5-1;
        pools.updatePoolConfig(usdPoolId, testConfig);
        vm.expectRevert(IPools.InvalidIM.selector);
        testConfig.imRatio = 1e7+1;
        pools.updatePoolConfig(usdPoolId, testConfig);

        vm.expectRevert(IPools.InvalidMM.selector);
        testConfig.imRatio = 4e6;
        testConfig.mmRatio = 4e6/5-1;
        pools.updatePoolConfig(usdPoolId, testConfig);
        vm.expectRevert(IPools.InvalidMM.selector);
        testConfig.mmRatio = 4e6/2+1;
        pools.updatePoolConfig(usdPoolId, testConfig);
        

        vm.expectRevert(IPools.InvalidMinimumMargin.selector);
        testConfig.mmRatio = 2e6;
        testConfig.minimumMargin = 1e4-1;
        pools.updatePoolConfig(usdPoolId, testConfig);

        vm.expectRevert(IPools.InvalidDust.selector);
        testConfig.minimumMargin = 100e6;
        testConfig.dust = 1e15-1;
        pools.updatePoolConfig(usdPoolId, testConfig);

        vm.expectRevert(IPools.InvalidMakerLimit.selector);
        testConfig.dust = 1e15;
        testConfig.makerLimit = 1e20-1;
        pools.updatePoolConfig(usdPoolId, testConfig);

        vm.expectRevert(IPools.InvalidFeeRatio.selector);
        testConfig.makerLimit = 50000000e20;
        testConfig.feeRatio = 1e5+1;
        pools.updatePoolConfig(usdPoolId, testConfig);

        testConfig.feeRatio = 4e4;

        pools.updatePoolConfig(usdPoolId, testConfig);
        IPools.PoolConfig memory upConfig = pools.getPoolConfig(usdPoolId);
        vm.assertEq(upConfig.addPaused, false);
        vm.assertEq(upConfig.removePaused, false);
        vm.assertEq(upConfig.liquidatePaused, false);
        vm.assertEq(upConfig.asset, address(usd));
        vm.assertEq(upConfig.pairId, getPairId("BTC/USD"));
        vm.assertEq(upConfig.precision, 1e6);
        vm.assertEq(upConfig.dust, testConfig.dust);
        vm.assertEq(upConfig.minimumMargin, testConfig.minimumMargin);
        vm.assertEq(upConfig.makerLimit, testConfig.makerLimit);
        vm.assertEq(upConfig.feeRatio, testConfig.feeRatio);
        vm.assertEq(upConfig.imRatio, testConfig.imRatio);
        vm.assertEq(upConfig.mmRatio, testConfig.mmRatio);
        vm.assertEq(upConfig.reserveRatio, testConfig.reserveRatio);
        vm.assertEq(upConfig.multiplier, testConfig.multiplier);


        vm.expectRevert(Governable.notGov.selector);
        vm.startPrank(a2);
        pools.updatePausedStatus(usdPoolId, true, true, true, true);
        vm.stopPrank();

        vm.expectRevert(IPools.PoolNotExist.selector);
        pools.updatePausedStatus(btcId, true, true, true, true);
        vm.expectRevert(IPools.InvalidPausedStatus.selector);
        pools.updatePausedStatus(usdPoolId, false, true, false, true);
        vm.expectRevert(IPools.InvalidPausedStatus.selector);
        pools.updatePausedStatus(usdPoolId, true, false, true, true);

        pools.updatePausedStatus(usdPoolId, true, false, false, false);
        upConfig = pools.getPoolConfig(usdPoolId);
        vm.assertEq(upConfig.addPaused, true);
        vm.assertEq(upConfig.removePaused, false);
        vm.assertEq(upConfig.liquidatePaused, false);
        vm.assertEq(pools.paused(), false);

        pools.updatePausedStatus(usdPoolId, true, true, false, true);
        upConfig = pools.getPoolConfig(usdPoolId);
        vm.assertEq(upConfig.addPaused, true);
        vm.assertEq(upConfig.removePaused, true);
        vm.assertEq(upConfig.liquidatePaused, false);
        vm.assertEq(pools.paused(), true);


        pools.updatePausedStatus(usdPoolId, true, true, true, true);
        upConfig = pools.getPoolConfig(usdPoolId);
        vm.assertEq(upConfig.addPaused, true);
        vm.assertEq(upConfig.removePaused, true);
        vm.assertEq(upConfig.liquidatePaused, true);
        vm.assertEq(pools.paused(), true);
    }

    function testMarketsConfig() public {
        vm.expectRevert(IMarkets.OnlyPools.selector);
        markets.createMarket(address(usd), getPairId("BTC/USD"));

        IMarkets.MarketConfig memory testConfig = IMarkets.MarketConfig({
            pairId: bytes32(0),
            margin: address(0),
            increasePaused: true,
            decreasePaused: true,
            liquidatePaused: true,
            precision: 0,
            feeRatio: 3e4,
            imRatio: 2e6,
            mmRatio: 1e6,

            multiplier: 10e8,

            minimumMargin: 100e6,
            dust: 1e15
        });

        vm.expectRevert(Governable.notGov.selector);
        vm.startPrank(a2);
        markets.updateMarket(btcId, testConfig);
        vm.stopPrank();
        vm.expectRevert(IMarkets.MarketNotExist.selector);
        markets.updateMarket(btcId, testConfig);

        
        vm.expectRevert(IMarkets.InvalidIM.selector);
        testConfig.imRatio = 1e5-1;
        markets.updateMarket(usdPoolId, testConfig);
        vm.expectRevert(IMarkets.InvalidIM.selector);
        testConfig.imRatio = 1e7+1;
        markets.updateMarket(usdPoolId, testConfig);

        vm.expectRevert(IMarkets.InvalidMM.selector);
        testConfig.imRatio = 4e6;
        testConfig.mmRatio = 4e6/5-1;
        markets.updateMarket(usdPoolId, testConfig);
        vm.expectRevert(IMarkets.InvalidMM.selector);
        testConfig.mmRatio = 4e6/2+1;
        markets.updateMarket(usdPoolId, testConfig);
        

        vm.expectRevert(IMarkets.InvalidMinimumMargin.selector);
        testConfig.mmRatio = 2e6;
        testConfig.minimumMargin = 1e4-1;
        markets.updateMarket(usdPoolId, testConfig);

        vm.expectRevert(IMarkets.InvalidDust.selector);
        testConfig.minimumMargin = 100e6;
        testConfig.dust = 1e15-1;
        markets.updateMarket(usdPoolId, testConfig);

        vm.expectRevert(IMarkets.InvalidFeeRatio.selector);
        testConfig.dust = 1e15;
        testConfig.feeRatio = 1e5+1;
        markets.updateMarket(usdPoolId, testConfig);

        testConfig.feeRatio = 4e4;

        markets.updateMarket(usdPoolId, testConfig);
        IMarkets.MarketConfig memory upConfig = markets.getMarketConfig(usdPoolId);
        vm.assertEq(upConfig.increasePaused, false);
        vm.assertEq(upConfig.decreasePaused, false);
        vm.assertEq(upConfig.liquidatePaused, false);
        vm.assertEq(upConfig.margin, address(usd));
        vm.assertEq(upConfig.pairId, getPairId("BTC/USD"));
        vm.assertEq(upConfig.precision, 1e6);
        vm.assertEq(upConfig.dust, testConfig.dust);
        vm.assertEq(upConfig.minimumMargin, testConfig.minimumMargin);
        vm.assertEq(upConfig.feeRatio, testConfig.feeRatio);
        vm.assertEq(upConfig.imRatio, testConfig.imRatio);
        vm.assertEq(upConfig.mmRatio, testConfig.mmRatio);
        vm.assertEq(upConfig.multiplier, 1e8);


        vm.expectRevert(Governable.notGov.selector);
        vm.startPrank(a2);
        markets.updatePausedStatus(usdPoolId, true, true, true, true);
        vm.stopPrank();

        vm.expectRevert(IMarkets.MarketNotExist.selector);
        markets.updatePausedStatus(btcId, true, true, true, true);
        vm.expectRevert(IMarkets.InvalidPausedStatus.selector);
        markets.updatePausedStatus(usdPoolId, false, true, false, true);
        vm.expectRevert(IMarkets.InvalidPausedStatus.selector);
        markets.updatePausedStatus(usdPoolId, true, false, true, true);

        markets.updatePausedStatus(usdPoolId, true, false, false, false);
        upConfig = markets.getMarketConfig(usdPoolId);
        vm.assertEq(upConfig.increasePaused, true);
        vm.assertEq(upConfig.decreasePaused, false);
        vm.assertEq(upConfig.liquidatePaused, false);
        vm.assertEq(markets.paused(), false);

        markets.updatePausedStatus(usdPoolId, true, true, false, true);
        upConfig = markets.getMarketConfig(usdPoolId);
        vm.assertEq(upConfig.increasePaused, true);
        vm.assertEq(upConfig.decreasePaused, true);
        vm.assertEq(upConfig.liquidatePaused, false);
        vm.assertEq(markets.paused(), true);


        markets.updatePausedStatus(usdPoolId, true, true, true, true);
        upConfig = markets.getMarketConfig(usdPoolId);
        vm.assertEq(upConfig.increasePaused, true);
        vm.assertEq(upConfig.decreasePaused, true);
        vm.assertEq(upConfig.liquidatePaused, true);
        vm.assertEq(markets.paused(), true);
    }

    function testUsdLiquidity() public {
        vm.assertEq(usd.balanceOf(address(this)), 1e18-110000e6);
        assertPosition(usdPoolId, address(this), 110000e20, 110000e20, 110000e20, block.timestamp, true);
        assertGlobalPosition(usdPoolId, 110000e20, 110000e20, 110000e20);
        assertPoolStatus(usdPoolId, true, 0, 0, 0);
        assertFundInfo(usdPoolId, 88000e20, 88000e20, 110000e20);
        assertEq(pools.getNetValue(usdPoolId), 1e10); 
        assertTickStatus(usdPoolId, 110e18, 0);

        usd.approve(address(pools), 1e18);
        pools.updatePausedStatus(usdPoolId, false, false, false, true);
        vm.expectRevert(IPools.Paused.selector);
        pools.addLiquidity(usdPoolId, address(this), 100e6, 1e23);
        pools.updatePausedStatus(usdPoolId, true, false, false, false);
        vm.expectRevert(IPools.AddPaused.selector);
        pools.addLiquidity(usdPoolId, address(this), 100e6, 1e23);
        pools.updatePausedStatus(usdPoolId, false, false, false, false);
        vm.expectRevert(IPools.InsufficientMargin.selector);
        pools.addLiquidity(usdPoolId, a2, 10e6, 1e22);
        vm.expectRevert(IPools.InvalidAmount.selector);
        pools.addLiquidity(usdPoolId, a2, 100e6, 1e22-1);
        vm.expectRevert(IPools.PositionDanger.selector);
        pools.addLiquidity(usdPoolId, a2, 100e6, 1e25);

        vm.expectEmit(address(pools));
        emit IPools.AddedLiquidity(a2, usdPoolId, 5e23, 5e23, 100e20, 1e10);
        pools.addLiquidity(usdPoolId, a2, 100e6, 5e23);
        vm.assertEq(usd.balanceOf(address(this)), 1e18-110000e6-100e6);
        assertPosition(usdPoolId, address(this), 110000e20, 110000e20, 110000e20, block.timestamp, true);
        assertPosition(usdPoolId, a2, 5e23, 5e23, 100e20, block.timestamp, false);

        assertGlobalPosition(usdPoolId, 110000e20+5e23, 110000e20+5e23, 110000e20+100e20);
        assertPoolStatus(usdPoolId, true, 0, 0, 0);
        assertFundInfo(usdPoolId, 88000e20+4e23, 88000e20+4e23, 110000e20+5e23);
        assertEq(pools.getNetValue(usdPoolId), 1e10); 
        assertTickStatus(usdPoolId, 115e18, 0);

        
        vm.startPrank(a2);
        vm.expectRevert(IPools.InvalidAmount.selector);
        pools.removeLiquidity(usdPoolId, 5e19);
        vm.stopPrank();
        pools.updatePausedStatus(usdPoolId, false, false, false, true);
        vm.startPrank(a2);
        vm.expectRevert(IPools.Paused.selector);
        pools.removeLiquidity(usdPoolId, 2500e20);
        vm.stopPrank();
        pools.updatePausedStatus(usdPoolId, true, true, false, false);
        vm.startPrank(a2);
        vm.expectRevert(IPools.RemovePaused.selector);
        pools.removeLiquidity(usdPoolId, 2500e20);
        vm.stopPrank();
        pools.updatePausedStatus(usdPoolId, false, false, false, false);

        vm.startPrank(a2);
        vm.expectEmit(address(pools));
        emit IPools.RemovedLiquidity(a2, usdPoolId, 2500e20, 2500e20, 50e20, 1e10, 0, 25e19);
        pools.removeLiquidity(usdPoolId, 2500e20);
        vm.assertEq(usd.balanceOf(address(im)), 25e5);
        vm.assertEq(usd.balanceOf(a2), 50e6-25e5);
        assertPosition(usdPoolId, a2, 2500e20, 2500e20, 50e20, block.timestamp, false);
        assertGlobalPosition(usdPoolId, 110000e20+2500e20, 110000e20+2500e20, 110000e20+50e20);
        assertTickStatus(usdPoolId, 1125e17, 0);
        vm.stopPrank();

        vm.warp(initTime + 7 days + 1);
        setPrice(btcId, 80000e8);
        vm.startPrank(a2);
        emit IPools.RemovedLiquidity(a2, usdPoolId, 2500e20, 2500e20, 50e20, 1e10, 0, 0);
        pools.removeLiquidity(usdPoolId, 2500e20);
        vm.assertEq(usd.balanceOf(a2), 100e6-25e5);
        assertPosition(usdPoolId, a2, 0, 0, 0, initTime, false);
        assertGlobalPosition(usdPoolId, 110000e20, 110000e20, 110000e20);
        assertFundInfo(usdPoolId, 88000e20, 88000e20, 110000e20);
        assertTickStatus(usdPoolId, 110e18, 0);
        vm.stopPrank();

        

        vm.expectRevert(abi.encodeWithSelector(IPools.PositionLocked.selector, initTime + 30 days));
        pools.removeLiquidity(usdPoolId, 110000e20);
        vm.warp(initTime + 30 days + 1);
        setPrice(btcId, 80000e8);
        uint256 b = usd.balanceOf(address(this));
        pools.removeLiquidity(usdPoolId, 110000e20);
        vm.assertEq(usd.balanceOf(address(this)), b+110000e6);
        assertPosition(usdPoolId, address(this), 0, 0, 0, initTime, false);
        assertGlobalPosition(usdPoolId, 0, 0, 0);
        assertFundInfo(usdPoolId, 0, 0, 0);
        assertTickStatus(usdPoolId, 0, 0);
    }

    function testBtcLiquidity() public {
        vm.assertEq(btc.balanceOf(address(this)), 1e18-2e9);
        assertPosition(btcPoolId, address(this), 2e20, 2e20, 2e20, block.timestamp, true);
        assertGlobalPosition(btcPoolId, 2e20, 2e20, 2e20);
        assertPoolStatus(btcPoolId, true, 0, 0, 0);
        assertFundInfo(btcPoolId, 16000e20, 16e19, 2e20);
        assertEq(pools.getNetValue(btcPoolId), 1e10); 
        assertTickStatus(btcPoolId, 8e20, 0);

        btc.approve(address(pools), 1e18);

        pools.updatePausedStatus(btcPoolId, false, false, false, true);
        vm.expectRevert(IPools.Paused.selector);
        pools.addLiquidity(btcPoolId, address(this), 100e6, 1e23);
        pools.updatePausedStatus(btcPoolId, true, false, false, false);
        vm.expectRevert(IPools.AddPaused.selector);
        pools.addLiquidity(btcPoolId, address(this), 100e6, 1e23);
        pools.updatePausedStatus(btcPoolId, false, false, false, false);
        vm.expectRevert(IPools.InsufficientMargin.selector);
        pools.addLiquidity(btcPoolId, a2, 1e6-1, 1e22);
        vm.expectRevert(IPools.InvalidAmount.selector);
        pools.addLiquidity(btcPoolId, a2, 1e7, 1e7-1);
        vm.expectRevert(IPools.PositionDanger.selector);
        pools.addLiquidity(btcPoolId, a2, 1e7, 1e20);


        vm.expectEmit(address(pools));
        emit IPools.AddedLiquidity(a2, btcPoolId, 5e18, 5e18, 1e18, 1e10);
        pools.addLiquidity(btcPoolId, a2, 1e7, 5e18);
        vm.assertEq(btc.balanceOf(address(this)), 1e18-2e9-1e7);
        assertPosition(btcPoolId, address(this), 2e20, 2e20, 2e20, block.timestamp, true);
        assertPosition(btcPoolId, a2, 5e18, 5e18, 1e18, block.timestamp, false);

        assertGlobalPosition(btcPoolId, 2e20+5e18, 2e20+5e18, 2e20+1e18);
        assertPoolStatus(btcPoolId, true, 0, 0, 0);
        assertFundInfo(btcPoolId, 164e22, 164e18, 2e20+5e18);
        assertEq(pools.getNetValue(btcPoolId), 1e10); 
        assertTickStatus(btcPoolId, 82e19, 0);

        
        vm.startPrank(a2);
        vm.expectRevert(IPools.InvalidAmount.selector);
        pools.removeLiquidity(btcPoolId, 1e15);
        vm.stopPrank();
        pools.updatePausedStatus(btcPoolId, false, false, false, true);
        vm.startPrank(a2);
        vm.expectRevert(IPools.Paused.selector);
        pools.removeLiquidity(btcPoolId, 25e17);
        vm.stopPrank();
        pools.updatePausedStatus(btcPoolId, true, true, false, false);
        vm.startPrank(a2);
        vm.expectRevert(IPools.RemovePaused.selector);
        pools.removeLiquidity(btcPoolId, 25e17);
        vm.stopPrank();
        pools.updatePausedStatus(btcPoolId, false, false, false, false);

        vm.startPrank(a2);
        vm.expectEmit(address(pools));
        emit IPools.RemovedLiquidity(a2, btcPoolId, 25e17, 25e17, 5e17, 1e10, 0, 25e14);
        pools.removeLiquidity(btcPoolId, 25e17);
        vm.assertEq(btc.balanceOf(address(im)), 25e3);
        vm.assertEq(btc.balanceOf(a2), 5e6-25e3);
        assertPosition(btcPoolId, a2, 25e17, 25e17, 5e17, block.timestamp, false);
        assertGlobalPosition(btcPoolId, 2e20+25e17, 2e20+25e17, 2e20+5e17);
        assertTickStatus(btcPoolId, 81e19, 0);
        vm.stopPrank();

        vm.warp(initTime + 7 days + 1);
        setPrice(ethId, 2325e8);

        vm.expectRevert(IPlugin.NotApprove.selector);
        pools.removeLiquidity(btcPoolId, a2, 25e17, a1);
        vm.startPrank(a2);
        pools.approve(address(this), true);
        vm.stopPrank();


        emit IPools.RemovedLiquidity(a2, btcPoolId, 25e17, 25e17, 5e17, 1e10, 0, 0);
        pools.removeLiquidity(btcPoolId, a2, 25e17, a1);
        vm.assertEq(btc.balanceOf(a1), 5e6);
        assertPosition(btcPoolId, a2, 0, 0, 0, initTime, false);
        assertGlobalPosition(btcPoolId, 2e20, 2e20, 2e20);
        assertFundInfo(btcPoolId, 16000e20, 16e19, 2e20);
        assertTickStatus(btcPoolId, 688172043010752688172, 0);

        

        vm.expectRevert(abi.encodeWithSelector(IPools.PositionLocked.selector, initTime + 30 days));
        pools.removeLiquidity(btcPoolId, 110000e20);
        vm.warp(initTime + 30 days + 1);
        setPrice(ethId, 2400e8);
        uint256 b = btc.balanceOf(address(this));
        pools.removeLiquidity(btcPoolId, 10e20);
        vm.assertEq(btc.balanceOf(address(this)), b+2e9);
        assertPosition(btcPoolId, address(this), 0, 0, 0, initTime, false);
        assertGlobalPosition(btcPoolId, 0, 0, 0);
        assertFundInfo(btcPoolId, 0, 0, 0);
        assertTickStatus(btcPoolId, 0, 0);
    }

    function testTradeUsdLong() public {
        int256 marginBalance = 0;
        int256 poolFee = 0;
        int256 unsettledFundingPayment = 0;
        int256 pnl = 0;
        int256 poolPnl = 0;
        int256 settledFunding = 0;
        int256 usedValue = 0;
        vm.assertEq(pools.fundingRatioGrowthGlobal(usdPoolId), 0);
        usd.approve(address(markets), 1e18);
        assertTickStatus(usdPoolId, 110e18, 0);

        vm.startPrank(a2);
        usd.mint(a2, 1e12);
        usd.approve(address(markets), 1e12);
        vm.expectRevert(IMarkets.InvalidMarketId.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdId,
            taker: a2,
            direction: true,
            margin: 1e6,
            amount: 1e15
        }));

        vm.expectRevert(IMarkets.InsufficientMargin.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 50e6-1,
            amount: 1e15+1
        }));

        vm.expectRevert(IMarkets.InvalidAmount.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 100e6,
            amount: 1e15
        }));

        
        vm.expectRevert(abi.encodeWithSelector(IMatchingEngine.LiquidityShortage.selector, 3e20, 11e19));
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 100e6,
            amount: 3e20
        }));

        vm.expectRevert(IPools.PositionDanger.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 50e6,
            amount: 1e19
        }));

        
        
        vm.expectEmit(address(markets));
        emit IMarkets.SettledFunding(usdPoolId, a2, 0, 0, 0);
        emit IMarkets.IncreasedPosition(usdPoolId, a2, true, 2000e6, 6e19, 4904402544000000000000000, 1961761017600000000000);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 2000e6,
            amount: 6e19
        }));
        vm.stopPrank();
        poolFee = 1961761017600000000000/2;
        usedValue = 4904402544000000000000000;
        {
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), 0);
            assertPoolStatus(usdPoolId, true, 6e19, 4904402544000000000000000, 2000e20-1961761017600000000000);
            assertPoolStatus(usdPoolId, false, 0, 0, 0);
            assertGlobalPosition(usdPoolId, 110000e20, 110000e20+980880508800000000000, 110000e20+poolFee);
            assertTickStatus(usdPoolId, 110e18, 6e19);
        }
        

        vm.warp(block.timestamp + 1 days + 300);
        setPrice(btcId, 80010e8);
        assertMarketPrice(usdPoolId, 8379229e8);
        assertTickStatus(usdPoolId, 110e18, 6e19);
        
        unsettledFundingPayment = 36789974172000000000000;
        vm.expectEmit(address(pools));
        emit IPools.UpdatedFundingRatio(usdPoolId, 255454, 613166236200000000000, unsettledFundingPayment);
        pools.addLiquidity(usdPoolId, a1, 10000000e6, 140000000e20);
        assertMarketPrice(usdPoolId, 8379229e8);
        {
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), unsettledFundingPayment);
            assertGlobalPosition(usdPoolId, 140000000e20+110000e20, 141801843246e17+110000e20+poolFee, 110000e20+10000000e20+poolFee);
            assertFundInfo(usdPoolId, 1e28, (141801843246e17+110000e20+poolFee)*8/10, 141801843246e17+110000e20+poolFee-usedValue);
            assertTickStatus(usdPoolId, 124984376952880889888763, 6e19);
        }
        

        vm.warp(block.timestamp + 12 hours + 600);
        setPrice(btcId, 80100e8);
        {
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), unsettledFundingPayment);
            assertTickStatus(usdPoolId, 124984376952880889888763, 6e19);
            assertMarketPrice(usdPoolId, 8388654e8);
        }


        vm.expectEmit(address(markets));
        unsettledFundingPayment += 735918750000000000000;
        emit IMarkets.SettledFunding(usdPoolId, a2, 6e19, unsettledFundingPayment, 625431548700000000000);
        emit IMarkets.IncreasedPosition(usdPoolId, a2, true, 10000e20, 2e20, 16777985018400000000000000, 6711194007360000000000);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 10000e6,
            amount: 2e20
        }));
        poolFee += 6711194007360000000000/2;
        usedValue += 16777985018400000000000000;
        assertMarketPrice(usdPoolId, 8389330e8);

        vm.warp(block.timestamp + 12 hours + 1);
        setPrice(btcId, 80150e8);
        {
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), unsettledFundingPayment);
            assertTickStatus(usdPoolId, 124984376952880889888763, 26e19);
            assertMarketPrice(usdPoolId, 8394567e8);
            assertGlobalPosition(usdPoolId, 140000000e20+110000e20, 141801843246e17+110000e20+poolFee, 110000e20+10000000e20+poolFee);
            assertFundInfo(usdPoolId, 1e28, (141801843246e17+110000e20+poolFee)*8/10, 141801843246e17+110000e20+poolFee-usedValue);
        }
        

        vm.warp(block.timestamp + 6 days);
        setPrice(btcId, 80300e8);
        assertTickStatus(usdPoolId, 124984376952880889888763, 26e19);
        assertMarketPrice(usdPoolId, 8410277e8);

        
        vm.startPrank(a1);
        (marginBalance, ) = pools.removeLiquidity(usdPoolId, 10000000e20);
        unsettledFundingPayment += 407121e17;
        poolPnl = -17347142593822000000000;
        vm.stopPrank();
        {
            vm.assertEq(marginBalance, 714112228574);
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), unsettledFundingPayment);
            assertGlobalPosition(usdPoolId, 130000000e20+110000e20, 141801843246e17+110000e20+poolFee-10128529415e17, 1011000000e18-71428570e18+poolFee-poolPnl);
            assertFundInfo(usdPoolId, 1e28, (141801843246e17+110000e20+poolFee-10128529415e17)*8/10, 141801843246e17+110000e20+poolFee-10128529415e17-usedValue);
            assertMarketPrice(usdPoolId, 8410277e8);
            assertTickStatus(usdPoolId, 124533001245330012453300, 26e19);
        }


        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a1,
            direction: false,
            margin: 20000e6,
            amount: 1e20
        }));
        usedValue += 8054616261307000000000000;
        poolFee += 16109232522614e8;
        {
            assertTickStatus(usdPoolId, 124533001245330012453300, 16e19);
            assertMarketPrice(usdPoolId, 8030515e8);
            assertGlobalPosition(usdPoolId, 130000000e20+110000e20, 141801843246e17+110000e20+poolFee-10128529415e17, 1011000000e18-71428570e18+poolFee-poolPnl);
            assertFundInfo(usdPoolId, 1e28, (141801843246e17+110000e20+poolFee-10128529415e17)*8/10, 141801843246e17+110000e20+poolFee-10128529415e17-usedValue);
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), unsettledFundingPayment);
        }


        markets.addMargin(usdPoolId, a2, true, 5000e6);
        assertGlobalPosition(usdPoolId, 130000000e20+110000e20, 141801843246e17+110000e20+poolFee-10128529415e17, 1011000000e18-71428570e18+poolFee-poolPnl);
        assertFundInfo(usdPoolId, 1e28, (141801843246e17+110000e20+poolFee-10128529415e17)*8/10, 141801843246e17+110000e20+poolFee-10128529415e17-usedValue);


        vm.startPrank(a2);
        (marginBalance, , ) = markets.decreasePosition(usdPoolId, true, 78e18);
        poolFee += 2505340103587200000000/2;
        usedValue -= 6504716268720000000000000;
        settledFunding = unsettledFundingPayment * 3 / 10;
        unsettledFundingPayment -= settledFunding;
        pnl = -241366009752000000000000;
        vm.stopPrank();
        {
            vm.assertEq(marginBalance, 2400553657);
            assertTickStatus(usdPoolId, 124533001245330012453300, 82e18);
            assertMarketPrice(usdPoolId, 8030264e8);
            assertGlobalPosition(usdPoolId, 130000000e20+110000e20, 141801843246e17+110000e20+poolFee-10128529415e17-pnl+settledFunding, 1011000000e18-71428570e18+poolFee-poolPnl-pnl);
            assertFundInfo(usdPoolId, 1e28, (141801843246e17+110000e20+poolFee-10128529415e17-pnl+settledFunding)*8/10, 141801843246e17+110000e20+poolFee-10128529415e17-pnl+settledFunding-usedValue);
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), unsettledFundingPayment);
        }

        
        vm.startPrank(a1);
        vm.expectRevert(IMarkets.InvalidAmount.selector);
        markets.decreasePosition(usdPoolId, false, -1e20);
        vm.expectRevert(IMarkets.NotPosition.selector);
        markets.decreasePosition(usdPoolId, true, 1e20);


        (marginBalance, , ) = markets.decreasePosition(usdPoolId, false, 1e20);
        poolFee += 160608510194e10;
        usedValue -= 8054616261307000000000000;
        pnl += 24190751607000000000000;
        vm.stopPrank();
        {
            vm.assertEq(marginBalance, 20177567348);
            assertTickStatus(usdPoolId, 124533001245330012453300, 182e18);
            assertMarketPrice(usdPoolId, 8030586e8);
            assertGlobalPosition(usdPoolId, 130000000e20+110000e20, 141801843246e17+110000e20+poolFee-10128529415e17-pnl+settledFunding, 1011000000e18-71428570e18+poolFee-poolPnl-pnl);
            assertFundInfo(usdPoolId, 1e28, (141801843246e17+110000e20+poolFee-10128529415e17-pnl+settledFunding)*8/10, 141801843246e17+110000e20+poolFee-10128529415e17-pnl+settledFunding-usedValue);
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), unsettledFundingPayment);
        }
        

        vm.startPrank(a2);
        (marginBalance, , ) = markets.decreasePosition(usdPoolId, true, 182e18);
        poolFee += 5845681460819200000000/2;
        usedValue -= 15177671293680000000000000;
        pnl += -563467641632000000000000;
        settledFunding += unsettledFundingPayment;
        unsettledFundingPayment = 0;
        vm.stopPrank();
        {
            vm.assertEq(marginBalance, 5598490133);
            assertTickStatus(usdPoolId, 124533001245330012453300, 0);
            assertMarketPrice(usdPoolId, 80300e10);
            assertGlobalPosition(usdPoolId, 130000000e20+110000e20, 141801843246e17+110000e20+poolFee-10128529415e17-pnl+settledFunding, 1011000000e18-71428570e18+poolFee-poolPnl-pnl);
            assertFundInfo(usdPoolId, 1e28, (141801843246e17+110000e20+poolFee-10128529415e17-pnl+settledFunding)*8/10, 141801843246e17+110000e20+poolFee-10128529415e17-pnl+settledFunding-usedValue);
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), unsettledFundingPayment);
            assertPoolStatus(usdPoolId, true, 0, 0, 0);
            assertPoolStatus(usdPoolId, false, 0, 0, 0);
        }
        
        

        vm.startPrank(a1);
        pools.removeLiquidity(usdPoolId, 180000000e20);
        poolPnl += 745752042593822000000000;
        vm.stopPrank();
        {
            assertTickStatus(usdPoolId, 111005778225134591282, 0);
            assertMarketPrice(usdPoolId, 80300e10);
            int256 pv = 141801843246e17+110000e20+poolFee-10128529415e17-pnl+settledFunding-13168059788e18;
            assertGlobalPosition(usdPoolId, 110000e20, pv, 1011000000e18-71428570e18-92857143e19+poolFee-poolPnl-pnl);
            assertFundInfo(usdPoolId, pv*8/10, pv*8/10, pv);
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), 0);
            assertPoolStatus(usdPoolId, true, 0, 0, 0);
            assertPoolStatus(usdPoolId, false, 0, 0, 0);
        }


        vm.warp(initTime + 30 days + 1);
        setPrice(btcId, 80200e8);
        pools.removeLiquidity(usdPoolId, 100000000e20);
        {
            assertTickStatus(usdPoolId, 0, 0);
            assertMarketPrice(usdPoolId, 80200e10);
            assertGlobalPosition(usdPoolId, 0, 0, 0);
            assertPoolStatus(usdPoolId, true, 0, 0, 0);
            assertPoolStatus(usdPoolId, false, 0, 0, 0);
            vm.assertEq(pools.unsettledFundingPayment(usdPoolId), 0);
        }
        
        vm.assertLe(usd.balanceOf(address(this)), pools.rewardAmounts(address(usd))+2e18);
        vm.expectRevert(IPools.OnlyMarkets.selector);
        pools.takerAddMargin(btcPoolId, false, 1e7);
    }

    function testTradeBtcShort() public {
        int256 poolFee = 0;
        int256 poolPnl = 0;
        int256 unsettledFundingPayment = 0;
        int256 pnl = 0;
        int256 settledFunding = 0;
        int256 marginBalance = 0;
        int256 usedValue;
        vm.assertEq(pools.fundingRatioGrowthGlobal(btcPoolId), 0);
        btc.approve(address(markets), 1e18);
        {
            assertTickStatus(btcPoolId, 8e20, 0);
            assertPoolStatus(btcPoolId, true, 0, 0, 0);
            assertPoolStatus(btcPoolId, false, 0, 0, 0);
            assertGlobalPosition(btcPoolId, 2e20, 2e20, 2e20);
            vm.assertEq(pools.unsettledFundingPayment(btcPoolId), 0);
        }
        

        vm.expectRevert(IPools.PositionDanger.selector);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: false,
            margin: 1e7,
            amount: 52e19
        }));

        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: false,
            margin: 1e7,
            amount: 1e20
        }));
        poolFee += 3984080000000000;
        usedValue += 1992040e13;
        {
            assertTakerPosition(btcPoolId, a2, false, -1e20, 1992040e17, 992031840000000000, 0, 0);
            assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
            assertGlobalPosition(btcPoolId, 2e20, 2e20+poolFee, 2e20+poolFee);
            assertPoolStatus(btcPoolId, true, 0, 0, 0);
            assertPoolStatus(btcPoolId, false, 1e20, 1992040e17, 992031840000000000);
            assertFundInfo(btcPoolId, (20000e20+poolFee*10000)*8/10, (20e19+poolFee)*8/10, 2e20-usedValue+poolFee);
            assertTickStatus(btcPoolId, 8e20, -1e20);
            assertMarketPrice(btcPoolId, 1983e10);
        }

        
        
        vm.warp(block.timestamp + 1 days + 300);
        setPrice(ethId, 2005e8);

        pools.addLiquidity(btcPoolId, a1, 10000000e9, 140000000e20);
        unsettledFundingPayment += 11027299500000000;
        {
            assertEq(marginBalance, 0);
            assertTakerPosition(btcPoolId, a2, false, -1e20, 1992040e17, 992031840000000000, 0, 0);
            assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
            assertGlobalPosition(btcPoolId, 2e20+140000000e20, 2e20+140101227952e17+poolFee, 2e20+10000000e20+poolFee);
            assertPoolStatus(btcPoolId, true, 0, 0, 0);
            assertPoolStatus(btcPoolId, false, 1e20, 1992040e17, 992031840000000000);
            assertFundInfo(btcPoolId, 1e26, (2e20+140101227952e17+poolFee)*8/10, 140101227952e17+2e20-usedValue+poolFee);
            assertTickStatus(btcPoolId, 49875311720698254364000, -1e20);
            assertMarketPrice(btcPoolId, 198795e8);
            vm.assertEq(pools.unsettledFundingPayment(btcPoolId), unsettledFundingPayment);
        }


        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: false,
            margin: 2e9,
            amount: 120e20
        }));
        poolFee += 475244178728799999;
        usedValue += 2376220893643999999999;
        {
            assertTakerPosition(btcPoolId, a2, false, -1e20-120e20, 1992040e17+23762208936439999999999990, 992031840000000000+199049511642542400000, -1102729950000000000, unsettledFundingPayment);
            assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
            assertGlobalPosition(btcPoolId, 2e20+140000000e20, 2e20+140101227952e17+poolFee, 2e20+10000000e20+poolFee);
            assertPoolStatus(btcPoolId, true, 0, 0, 0);
            assertPoolStatus(btcPoolId, false, 1e20+120e20, 1992040e17+23762208936439999999999990, 992031840000000000+199049511642542400000);
            assertFundInfo(btcPoolId, 1e26, (2e20+140101227952e17+poolFee)*8/10, 140101227952e17+2e20+poolFee-usedValue);
            assertTickStatus(btcPoolId, 49875311720698254364000, -121e20);
            assertMarketPrice(btcPoolId, 1968097e7);
            vm.assertEq(pools.unsettledFundingPayment(btcPoolId), unsettledFundingPayment);
        }

        vm.warp(block.timestamp + 2 days + 1);
        setPrice(ethId, 1998e8);
        vm.startPrank(a2);
        (marginBalance, , ) = markets.decreasePosition(btcPoolId, false, 115e20);
        unsettledFundingPayment = 414384582484024650;
        poolFee += 459416383738002000;
        pnl = -19757556222835426320;
        settledFunding = 7942370635015975350;
        usedValue -= 2277324362467159573679;
        vm.stopPrank();
        {
            vm.assertEq(marginBalance, 1615033678);
            assertTakerPosition(btcPoolId, a2, false, -6e20, 1188169311768404263200000, 9919416007529263830, -8000025750000000000, unsettledFundingPayment);
            assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
            assertGlobalPosition(btcPoolId, 2e20+140000000e20, 2e20+140101227952e17+poolFee-pnl+settledFunding, 2e20+10000000e20+poolFee-pnl);
            assertPoolStatus(btcPoolId, true, 0, 0, 0);
            assertPoolStatus(btcPoolId, false, 6e20, 1188169311768404263200000, 9919416007529263830);
            assertFundInfo(btcPoolId, 1e26, (2e20+140101227952e17+poolFee-pnl+settledFunding)*8/10, 140101227952e17+2e20+poolFee-118816931176840426320-pnl+settledFunding);
            assertTickStatus(btcPoolId, 49875311720698254364000, -6e20);
            assertMarketPrice(btcPoolId, 1996747e7);
            vm.assertEq(pools.unsettledFundingPayment(btcPoolId), unsettledFundingPayment);
        }

        // remove a1 all
        vm.startPrank(a1);
        (marginBalance, ) = pools.removeLiquidity(btcPoolId, 170000000e20);
        poolPnl += 29400000000000000000;
        vm.stopPrank();
        {
            vm.assertEq(marginBalance, 9859899066048000);
            assertTakerPosition(btcPoolId, a2, false, -6e20, 1188169311768404263200000, 9919416007529263830, -8000025750000000000, unsettledFundingPayment);
            assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
            assertGlobalPosition(btcPoolId, 2e20, 2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding, 2e20+poolFee-pnl-poolPnl);
            assertPoolStatus(btcPoolId, true, 0, 0, 0);
            assertPoolStatus(btcPoolId, false, 6e20, 1188169311768404263200000, 9919416007529263830);
            assertFundInfo(btcPoolId, 1593908572002665629350000, (2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding)*8/10, 140101227952e17+2e20+poolFee-usedValue-pnl-140101228246e17+settledFunding);
            assertTickStatus(btcPoolId, 797752038039312126801, -6e20);
            assertMarketPrice(btcPoolId, 1996747e7);
            vm.assertEq(pools.unsettledFundingPayment(btcPoolId), unsettledFundingPayment);
            vm.assertEq(btc.balanceOf(address(im)), 140101227952000);
            vm.assertEq(im.poolBalances(btcPoolId), 140101227952000);
            vm.assertEq(btc.balanceOf(a1), 9859899066048000);
        }


        vm.warp(block.timestamp + 1 days + 1);
        setPrice(ethId, 1997e8);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a1,
            direction: true,
            margin: 6e7,
            amount: 3e20
        }));
        poolFee += 11982883780338000;
        unsettledFundingPayment += 16611113898e8; 
        usedValue += 59914418901690000000;
        {
            assertTakerPosition(btcPoolId, a1, false, 0, 0, 0, 0, 0);
            assertTakerPosition(btcPoolId, a1, true, 3e20, 599144189016900000000000, 5976034232439324000, -35685215580000000000, 0);
            assertGlobalPosition(btcPoolId, 2e20, 2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding, 2e20+poolFee-pnl-poolPnl);
            assertPoolStatus(btcPoolId, true, 3e20, 599144189016900000000000, 5976034232439324000);
            assertPoolStatus(btcPoolId, false, 6e20, 1188169311768404263200000, 9919416007529263830);
            assertFundInfo(btcPoolId, 1594004435072908333350000, (2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding)*8/10, 2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding-usedValue);
            assertTickStatus(btcPoolId, 797752038039312126801, -3e20);
            assertMarketPrice(btcPoolId, 1935814e7); 
            vm.assertEq(pools.unsettledFundingPayment(btcPoolId), unsettledFundingPayment);
        } 

        vm.startPrank(a2);
        (marginBalance, , ) = markets.decreasePosition(btcPoolId, false, 10e20);
        vm.stopPrank();
        poolFee += 48255208229477332/2;
        pnl += -1821089396851573680;
        settledFunding += unsettledFundingPayment;
        unsettledFundingPayment = 0;
        usedValue -= 118816931176840426320;
        {
            vm.assertEq(marginBalance, 59745754);
            assertTakerPosition(btcPoolId, a1, false, 0, 0, 0, 0, 0);
            assertTakerPosition(btcPoolId, a1, true, 3e20, 599144189016900000000000, 5976034232439324000, -35685215580000000000, 0);
            assertTakerPosition(btcPoolId, a2, false, 0, 0, 0, 0, 0);
            assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
            assertGlobalPosition(btcPoolId, 2e20, 2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding, 2e20+poolFee-pnl-poolPnl);
            assertPoolStatus(btcPoolId, true, 3e20, 599144189016900000000000, 5976034232439324000);
            assertPoolStatus(btcPoolId, false, 0, 0, 0);
            assertFundInfo(btcPoolId, 1625370138858921368080000, (2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding)*8/10, 2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding-usedValue);
            assertTickStatus(btcPoolId, 797752038039312126801, 3e20);
            assertMarketPrice(btcPoolId, 2058185e7);
            vm.assertEq(pools.unsettledFundingPayment(btcPoolId), 0);
        }


        vm.warp(block.timestamp + 3 days + 1);
        setPrice(ethId, 1995e8);
        vm.startPrank(a1);
        (marginBalance, , ) = markets.decreasePosition(btcPoolId, true, 10e20);
        poolFee += 23952806284050000/2;
        pnl += -32403191565000000;
        settledFunding += 549519957000000000;
        usedValue = 0;
        vm.stopPrank();
        {
            vm.assertEq(marginBalance, 53701582);
            assertTakerPosition(btcPoolId, a1, false, 0, 0, 0, 0, 0);
            assertTakerPosition(btcPoolId, a1, true, 0, 0, 0, 0, 0);
            assertTakerPosition(btcPoolId, a2, false, 0, 0, 0, 0, 0);
            assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
            assertGlobalPosition(btcPoolId, 2e20, 2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding, 2e20+poolFee-pnl-poolPnl);
            assertPoolStatus(btcPoolId, true, 0, 0, 0);
            assertPoolStatus(btcPoolId, false, 0, 0, 0);
            assertFundInfo(btcPoolId, 1630121335272577568080000, (2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding)*8/10, 2e20+140101227952e17+poolFee-pnl-140101228246e17+settledFunding-usedValue);
            assertTickStatus(btcPoolId, 797752038039312126801, 0);
            assertMarketPrice(btcPoolId, 1995e10);
            vm.assertEq(pools.unsettledFundingPayment(btcPoolId), 0);
        }

        vm.warp(block.timestamp + 30 days + 1);
        setPrice(ethId, 19905e8);
        (marginBalance, ) = pools.removeLiquidity(btcPoolId, 10000000e20);
        {
            vm.assertEq(marginBalance, 2037651669);
            assertTakerPosition(btcPoolId, a1, false, 0, 0, 0, 0, 0);
            assertTakerPosition(btcPoolId, a1, true, 0, 0, 0, 0, 0);
            assertTakerPosition(btcPoolId, a2, false, 0, 0, 0, 0, 0);
            assertTakerPosition(btcPoolId, a2, true, 0, 0, 0, 0, 0);
            assertGlobalPosition(btcPoolId, 0, 0, 0);
            assertPoolStatus(btcPoolId, true, 0, 0, 0);
            assertPoolStatus(btcPoolId, false, 0, 0, 0);
            assertTickStatus(btcPoolId, 0, 0);
            assertMarketPrice(btcPoolId, 19905e10);
            vm.assertEq(pools.unsettledFundingPayment(btcPoolId), 0);

            vm.assertGe(btc.balanceOf(address(pools)), uint256(poolFee*1e9/1e20)-1e4);
            vm.assertLe(btc.balanceOf(address(pools)), uint256(poolFee*1e9/1e20)+1e4);
        }
    }

    function testTpLimitUSD() public {
        int256 marginBalance;
        usd.approve(address(markets), 1e18);

        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 100e6,
            amount: 1e18
        }));

        setPrice(btcId, 200000e8);
        vm.startPrank(a2);
        (marginBalance, , ) = markets.decreasePosition(usdPoolId, true, 1e20);
        vm.stopPrank();
        assertEq(marginBalance, 899061822);
        assertEq(usd.balanceOf(a2), 899061822);


        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: false,
            margin: 100e6,
            amount: 1e18
        }));

        vm.warp(block.timestamp + 100000 days + 1);
        setPrice(btcId, 200e8);

        vm.startPrank(a2);
        (marginBalance, , ) = markets.decreasePosition(usdPoolId, false, 3e17);
        vm.stopPrank();
        assertEq(marginBalance, 629623452);
        assertEq(usd.balanceOf(a2), 899061822+629623452);
    }

    function testTpLimitBTC() public {
        int256 marginBalance;
        btc.approve(address(markets), 1e18);
        btc.approve(address(pools), 1e18);
        

        setPrice(ethId, 121e3); 
        pools.addLiquidity(btcPoolId, address(this), 7e9, 10e20);


        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: true,
            margin: 1e8,
            amount: 1000000e20  // 1000000*121e3/1e8=1210
        }));

        vm.warp(block.timestamp + 5 days + 1);
        setPrice(ethId, 121e5); 

        vm.startPrank(a2);
        (marginBalance, , ) = markets.decreasePosition(btcPoolId, true, 150000e20);
        vm.stopPrank();
        vm.assertEq(marginBalance, 32422444);
        vm.assertEq(btc.balanceOf(a2), 32422444);


        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: false,
            margin: 1e9,
            amount: 800000e20 
        }));

        vm.warp(block.timestamp + 800000 days + 1);
        setPrice(ethId, 100); 

        vm.startPrank(a2);
        (marginBalance, , ) = markets.decreasePosition(btcPoolId, false, 700000e20);
        vm.stopPrank();
        vm.assertEq(marginBalance, 9340786134);
        vm.assertEq(btc.balanceOf(a2), 32422444+9340786134);
    }

    function assertPosition(bytes32 poolId, address maker, int256 amount, int256 value, int256 margin, uint256 increaseTime, bool initial) private view {
        IPools.Position memory pos = pools.getPosition(poolId, maker);
        vm.assertEq(pos.amount, amount, "MPA");
        vm.assertEq(pos.margin, margin, "MPM");
        vm.assertEq(pos.value, value, "MPV");
        vm.assertEq(pos.increaseTime, increaseTime, "MPT");
        vm.assertEq(pos.initial, initial, "MPI");
    }

    function assertGlobalPosition(bytes32 poolId, int256 amount, int256 value, int256 margin) private view {
        (int256 gAmount, int256 gValue, int256 gMargin) = pools.globalPosition(poolId);
        vm.assertGe(gAmount, amount, "GPAG");
        vm.assertLt(gAmount, amount+1e10, "GPAL");
        if (gAmount != 0) {
            vm.assertGe(gValue, value, "GPVG");
            vm.assertLt(gValue, value+1e10, "GPVL");
            vm.assertGe(gMargin, margin, "GPMG");
            vm.assertLt(gMargin, margin+1e10, "GPML");
        }
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
        vm.assertLt(s.makerAmount, makerAmount+1e10, "TSAL");
        vm.assertGe(s.position, position, "TSPG");
        vm.assertLt(s.position, position+1e10, "TSPL");
    }

    function assertMarketPrice(bytes32 poolId, int256 price) public view {
        int256 p = pools.getMarketPrice(poolId, 0);
        vm.assertGe(p, price, "MPG");
        vm.assertLt(p, price+1e8, "MPL");
    }
}