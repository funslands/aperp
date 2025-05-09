// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Test.sol";
import "../src/core/MatchingEngine.sol";
import "../src/libraries/Constant.sol";

contract MatchingEngineTest is Test {
    MatchingEngine public me;

    address public a1 = vm.addr(0xff323);
    address public a2 = vm.addr(0xff322);
    address public pools = vm.addr(0xff321);
    bytes32 poolId;

    function setUp() public {
        me = new MatchingEngine(pools);
        poolId = keccak256(abi.encode(a1, a2));
    }

    function updateConfig() private {
        MatchingEngine.TickConfig[] memory config = new MatchingEngine.TickConfig[](6);

        MatchingEngine.TickConfig memory c1;
        MatchingEngine.TickConfig memory c2;
        MatchingEngine.TickConfig memory c3;
        MatchingEngine.TickConfig memory c4;
        MatchingEngine.TickConfig memory c5;
        
        c1.usageRatio = 1e5; // 0.1%
        c1.slippage = 5e4;   // 0.05%
        c2.usageRatio = 5e6; // 5%
        c2.slippage = 1e5;   // 0.1%
        c3.usageRatio = 2e7; // 20%
        c3.slippage = 5e5;   // 0.5%
        c4.usageRatio = 6e7; // 60%
        c4.slippage = 3e6;   // 3%
        c5.usageRatio = 1e8; // 100%
        c5.slippage = 1e7;   // 10%
        config[1] = c1;
        config[2] = c2;
        config[3] = c3;
        config[4] = c4;
        config[5] = c5;

        me.updateTickConfig(poolId, config);
    }

    function testCheckTickConfig() public view {
        MatchingEngine.TickConfig[] memory config1 = new MatchingEngine.TickConfig[](2);

        MatchingEngine.TickConfig memory c0;
        MatchingEngine.TickConfig memory c1;
        MatchingEngine.TickConfig memory c2;
        c0.slippage = 0;
        c0.usageRatio = 0;
        config1[0] = c0;
        
        c1.usageRatio = Constant.BASIS_POINTS_DIVISOR;
        c1.slippage = 1e7;
        config1[1] = c1;

        bool result = me.checkTickConfig(config1);
        vm.assertFalse(result);

        MatchingEngine.TickConfig[] memory config2 = new MatchingEngine.TickConfig[](3);
        c0.usageRatio = 1;
        c0.slippage = 0;
        config2[0] = c0;

        c1.usageRatio = 1e7;
        c1.slippage = 1e6;
        config2[1] = c1;

        c2.usageRatio = Constant.BASIS_POINTS_DIVISOR;
        c2.slippage = 1e7;
        config2[2] = c2;

        result = me.checkTickConfig(config2);
        vm.assertFalse(result);

        c0.usageRatio = -1;
        config2[0] = c0;
        result = me.checkTickConfig(config2);
        vm.assertFalse(result);

        c0.usageRatio = 0;
        c0.slippage = -1;
        config2[0] = c0;
        result = me.checkTickConfig(config2);
        vm.assertFalse(result);

        c0.usageRatio = 0;
        c0.slippage = 0;
        config2[0] = c0;
        c2.usageRatio = Constant.BASIS_POINTS_DIVISOR-1;
        config2[2] = c2;
        result = me.checkTickConfig(config2);
        vm.assertFalse(result);

        c2.usageRatio = Constant.BASIS_POINTS_DIVISOR+1;
        config2[2] = c2;
        result = me.checkTickConfig(config2);
        vm.assertFalse(result);

        c2.usageRatio = Constant.BASIS_POINTS_DIVISOR;
        c2.slippage = Constant.BASIS_POINTS_DIVISOR+1;
        config2[2] = c2;
        result = me.checkTickConfig(config2);
        vm.assertFalse(result);

        c1.usageRatio = c0.usageRatio;
        config2[1] = c1;
        c2.usageRatio = Constant.BASIS_POINTS_DIVISOR;
        c2.slippage = Constant.BASIS_POINTS_DIVISOR;
        config2[2] = c2;
        result = me.checkTickConfig(config2);
        vm.assertFalse(result);

        c1.slippage = c0.slippage;
        config2[1] = c1;
        result = me.checkTickConfig(config2);
        vm.assertFalse(result);

        c1.slippage = c2.slippage;
        config2[1] = c1;
        result = me.checkTickConfig(config2);
        vm.assertFalse(result);

        c1.usageRatio = c2.usageRatio;
        config2[1] = c1;
        result = me.checkTickConfig(config2);
        vm.assertFalse(result);

        c1.usageRatio = 1e7;
        c1.slippage = 1e6;
        config2[1] = c1;
        result = me.checkTickConfig(config2);
        vm.assertTrue(result);
        

        MatchingEngine.TickConfig[] memory config11 = new MatchingEngine.TickConfig[](11);

        for(uint256 i=1; i<10; i++) {
            config11[i].usageRatio = int256(i)*1e6;
            config11[i].slippage = int256(i)*1e5;
        }

        config11[10].usageRatio = Constant.BASIS_POINTS_DIVISOR;
        config11[10].slippage = Constant.BASIS_POINTS_DIVISOR;
        result = me.checkTickConfig(config11);
        vm.assertFalse(result);
    }

    function testUpdateConfig() public {
        MatchingEngine.TickConfig[] memory config1 = new MatchingEngine.TickConfig[](2);

        MatchingEngine.TickConfig memory c1;
        MatchingEngine.TickConfig memory c2;

        c1.slippage = Constant.BASIS_POINTS_DIVISOR;
        c1.usageRatio = Constant.BASIS_POINTS_DIVISOR;

        vm.startPrank(a1);
        vm.expectRevert(IMatchingEngine.InvalidCall.selector);
        me.updateTickConfig(poolId, config1);
        vm.stopPrank();

        vm.expectRevert(IMatchingEngine.InvalidTickConfig.selector);
        me.updateTickConfig(poolId, config1);

        vm.startPrank(pools);
        vm.expectRevert(IMatchingEngine.InvalidTickConfig.selector);
        me.updateTickConfig(poolId, config1);
        vm.stopPrank();

        c1.usageRatio = 1e7;
        c1.slippage = 1e6;
        c2.usageRatio = Constant.BASIS_POINTS_DIVISOR;
        c2.slippage = 1e7;

        MatchingEngine.TickConfig[] memory config2 = new MatchingEngine.TickConfig[](3);
        config2[1] = c1;
        config2[2] = c2;
        me.updateTickConfig(poolId, config2);


        MatchingEngine.TickConfig memory c3;
        c1.usageRatio = 1e7;
        c1.slippage = 1e6;
        c1.usageRatio = 3e7;
        c1.slippage = 3e6;
        c3.usageRatio = Constant.BASIS_POINTS_DIVISOR;
        c3.slippage = 1e7;

        MatchingEngine.TickConfig[] memory config3 = new MatchingEngine.TickConfig[](4);
        config3[1] = c1;
        config3[2] = c2;
        config3[3] = c3;
        me.updateTickConfig(poolId, config2);
    }

    function testUpdateFund() public {
        updateConfig();
        int256 price = 2000e10;
        vm.expectRevert(IMatchingEngine.OnlyPools.selector);
        me.updateFund(poolId, 2000000e20, price);

        vm.startPrank(pools);
        me.updateFund(poolId, 2000000e20, price);


        me.matching(IMatchingEngine.MatchingParams({
            poolId: poolId,
            tradeAmount: 100e20,
            price: price
        }));

        assertPoolStatus(poolId, 3, 100e20, 1e7, 233333);

        me.updateFund(poolId, 180000e20, price);
        assertPoolStatus(poolId, 6, 100e20, 1e8, 233333);
        vm.stopPrank();
    }

    function testMatching0() public {
        updateConfig();
        int256 price = 2000e10; // 1000$
        int256 makerFund = 100000000e20; // 100m USD
        vm.startPrank(pools);
        me.updateFund(poolId, makerFund, price);
        vm.stopPrank();
        assertPoolStatus(poolId, 0, 0, 0, 0);
        vm.assertEq(me.getMarketPrice(poolId, price), price);
        vm.assertEq(me.getMarketPrice(poolId, price*3), price*3);
        vm.assertEq(me.getMarketPrice(poolId, 100e10), 100e10);


        vm.startPrank(pools);
        MatchingEngine.MatchingParams memory params;
        params.poolId = poolId;
        params.tradeAmount = 10e20; // long 10
        params.price = price;
        assertMatching(params, 10e20, 20001e9, 20001e20);


        params.tradeAmount = -10e20; // short 10
        assertMatching(params, 10e20, 199992e8, 1999929e18);

        assertPoolStatus(poolId, 0, 0, 0, 0);


        params.tradeAmount = 600e20; // long 600
        assertMatching(params, 600e20, 200106e8, 120063673e18);
        assertPoolStatus(poolId, 2, 600e20, 1200000, 61224);

        params.tradeAmount = -15e20; // short 15
        assertMatching(params, 15e20, 200091e8, 3001377e18);
        assertPoolStatus(poolId, 2, 585e20, 1170000, 60918);

        params.tradeAmount = -600e20; // short 600
        assertMatching(params, 600e20, 199958e8, 119974893e18);
        assertPoolStatus(poolId, 1, -15e20, 30000, 15000);

        vm.assertEq(me.getMarketPrice(poolId, 2000e10), 199970e8);
        me.updateFund(poolId, 2000000e20, price);
        assertPoolStatus(poolId, 2, -15e20, 1500000, 15000);
        vm.assertEq(me.getMarketPrice(poolId, 2000e10), 199970e8);

        params.tradeAmount = -725e20;
        assertMatching(params, 725e20, 196307e8, 142322975e18);
        assertPoolStatus(poolId, 5, -740e20, 74000000, 5450000);

        params.tradeAmount = 550e20;
        assertMatching(params, 550e20, 199667e8, 109817040e18);
        assertPoolStatus(poolId, 3, -190e20, 19000000, 473333);


        assertPrice(poolId, 3000e10, 298580e8);
        me.updateFund(poolId, 12000000e20, 2500e10);
        assertPoolStatus(poolId, 3, -190e20, 3958333, 473333);
        assertPrice(poolId, 3000e10, 298580e8);

        params.tradeAmount = -500e20;
        assertMatching(params, 500e20, 199036e8, 99518009e18);
        assertPoolStatus(poolId, 3, -690e20, 14375000, 490649);

        params.tradeAmount = -500e20;
        assertMatching(params, 500e20, 198867e8, 99433645e18);
        assertPoolStatus(poolId, 4, -1190e20, 24791666, 799479);


        MatchingEngine.TickConfig[] memory config = new MatchingEngine.TickConfig[](6);

        MatchingEngine.TickConfig memory c1;
        MatchingEngine.TickConfig memory c2;
        MatchingEngine.TickConfig memory c3;
        MatchingEngine.TickConfig memory c4;
        MatchingEngine.TickConfig memory c5;
        
        c1.usageRatio = 5e5; // 0.5%
        c1.slippage = 5e4;   // 0.05%
        c2.usageRatio = 1e7; // 10%
        c2.slippage = 1e5;   // 0.1%
        c3.usageRatio = 3e7; // 30%
        c3.slippage = 5e5;   // 0.5%
        c4.usageRatio = 6e7; // 60%
        c4.slippage = 3e6;   // 3%
        c5.usageRatio = 1e8; // 100%
        c5.slippage = 1e7;   // 10%
        config[1] = c1;
        config[2] = c2;
        config[3] = c3;
        config[4] = c4;
        config[5] = c5;

        me.updateTickConfig(poolId, config);
        assertPoolStatus(poolId, 3, -1190e20, 24791666, 395833);


        params.tradeAmount = -500e20;
        assertMatching(params, 500e20, 198835e8, 99417535e18);
        assertPoolStatus(poolId, 4, -1690e20, 35208333, 934027);

        params.tradeAmount = 1300e20;
        assertMatching(params, 1300e20, 199974e8, 259966408e18);
        assertPoolStatus(poolId, 2, -390e20, 8125000, 90131);


        params.tradeAmount = 390e20;
        assertMatching(params, 390e20, 200040e8, 78015640e18);
        assertPoolStatus(poolId, 0, 0, 0, 0);
    }

    function assertPrice(bytes32 pId, int256 indexPrice, int256 p) public view {
        int256 price = me.getMarketPrice(pId, indexPrice);
        vm.assertGt(price, p);
        vm.assertLe(price, p+1e8);
    }


    function assertPoolStatus(bytes32 pId, uint256 currentTick, int256 position, int256 usageRatio, int256 slippage) public view {
        IMatchingEngine.TickStatus memory status = me.getStatus(pId);
        vm.assertEq(status.currentTick, currentTick, "PSCT");
        vm.assertGe(status.position, position, "PSPG");
        vm.assertLt(status.position, position+1e19, "PSPL");
        vm.assertGe(status.usageRatio, usageRatio, "PSURG");
        vm.assertLt(status.usageRatio, usageRatio+100, "PSURL");
        vm.assertGe(status.slippage, slippage, "PSSG");
        vm.assertLt(status.slippage, slippage+100, "PSSL");
    }

    function assertMatching(MatchingEngine.MatchingParams memory params, int256 amount, int256 price, int256 value) public {
        (int256 a, int256 v, int256 p) = me.matching(params);
        vm.assertEq(a, amount, "EA");
        vm.assertGe(p, price, "EP1");
        vm.assertLt(p, price+1e8, "EP2");
        vm.assertGe(v, value, "EV1");
        vm.assertLt(v, value+1e18, "EV2");
    }
}