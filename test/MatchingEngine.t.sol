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
        config[0] = IMatchingEngine.TickConfig({usageRatio: 0, slippage: 0});       // 0    0
        config[1] = IMatchingEngine.TickConfig({usageRatio: 1e5, slippage: 5e4});   // 0.1%  0.05%
        config[2] = IMatchingEngine.TickConfig({usageRatio: 5e6, slippage: 1e5});   // 5%   0.1%
        config[3] = IMatchingEngine.TickConfig({usageRatio: 2e7, slippage: 5e5});   // 20%  0.5%
        config[4] = IMatchingEngine.TickConfig({usageRatio: 6e7, slippage: 3e6});   // 60%  3%
        config[5] = IMatchingEngine.TickConfig({usageRatio: 1e8, slippage: 1e7});   // 100% 10%

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
        assertTickConfig(poolId, config2);

        IMatchingEngine.TickConfig[] memory config3 = new IMatchingEngine.TickConfig[](7);
        config3[0] = IMatchingEngine.TickConfig({usageRatio: 0, slippage: 0});
        config3[1] = IMatchingEngine.TickConfig({usageRatio: 1e6, slippage: 5e4});
        config3[2] = IMatchingEngine.TickConfig({usageRatio: 5e6, slippage: 30e4});
        config3[3] = IMatchingEngine.TickConfig({usageRatio: 1e7, slippage: 65e4});
        config3[4] = IMatchingEngine.TickConfig({usageRatio: 2e7, slippage: 145e4});
        config3[5] = IMatchingEngine.TickConfig({usageRatio: 5e7, slippage: 420e4});
        config3[6] = IMatchingEngine.TickConfig({usageRatio: 1e8, slippage: 1e7});
        me.updateTickConfig(poolId, config3);
        assertTickConfig(poolId, config3);


        MatchingEngine.TickConfig[] memory config4 = new MatchingEngine.TickConfig[](4);
        config4[0] = IMatchingEngine.TickConfig({usageRatio: 0, slippage: 0});
        config4[1] = IMatchingEngine.TickConfig({usageRatio: 1e7, slippage: 1e6});
        config4[2] = IMatchingEngine.TickConfig({usageRatio: 3e7, slippage: 3e6});
        config4[3] = IMatchingEngine.TickConfig({usageRatio: Constant.BASIS_POINTS_DIVISOR, slippage: 1e7});
        me.updateTickConfig(poolId, config4);
        assertTickConfig(poolId, config4);
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
        int256 price = 2000e10; // 2000$
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
        config[0] = IMatchingEngine.TickConfig({usageRatio: 0, slippage: 0});       // 0    0
        config[1] = IMatchingEngine.TickConfig({usageRatio: 5e5, slippage: 5e4});   // 0.5% 0.05%
        config[2] = IMatchingEngine.TickConfig({usageRatio: 1e7, slippage: 1e5});   // 10%  0.1%
        config[3] = IMatchingEngine.TickConfig({usageRatio: 3e7, slippage: 5e5});   // 30%  0.5%
        config[4] = IMatchingEngine.TickConfig({usageRatio: 6e7, slippage: 3e6});   // 60%  3%
        config[5] = IMatchingEngine.TickConfig({usageRatio: 1e8, slippage: 1e7});   // 100% 10%
        me.updateTickConfig(poolId, config);
        assertPoolStatus(poolId, 4, -1190e20, 24791666, 799479);


        params.tradeAmount = -500e20;
        assertMatching(params, 500e20, 197750e8, 98875001e18);
        assertPoolStatus(poolId, 4, -1690e20, 35208333, 1450520);

        params.tradeAmount = 1300e20;
        assertMatching(params, 1300e20, 199941e8, 259923413e18);
        assertPoolStatus(poolId, 3, -390e20, 8125000, 249450);


        params.tradeAmount = 390e20;
        assertMatching(params, 390e20, 200032e8, 78012533e18);
        assertPoolStatus(poolId, 0, 0, 0, 0);


        params.tradeAmount = 1000e20;
        assertMatching(params, 1000e20, 200286e8, 200286266e18);
        assertPoolStatus(poolId, 3, 1000e20, 20833333, 316666);

        MatchingEngine.TickConfig[] memory config1 = new MatchingEngine.TickConfig[](6);
        config1[0] = IMatchingEngine.TickConfig({usageRatio: 0, slippage: 0});       // 0    0
        config1[1] = IMatchingEngine.TickConfig({usageRatio: 1e6, slippage: 5e4});   // 1%   0.05%
        config1[2] = IMatchingEngine.TickConfig({usageRatio: 8e6, slippage: 1e5});   // 8%   0.1%
        config1[3] = IMatchingEngine.TickConfig({usageRatio: 2e7, slippage: 5e5});   // 20%  0.5%
        config1[4] = IMatchingEngine.TickConfig({usageRatio: 5e7, slippage: 3e6});   // 50%  3%
        config1[5] = IMatchingEngine.TickConfig({usageRatio: 1e8, slippage: 1e7});   // 100% 10%
        me.updateTickConfig(poolId, config1);
        assertPoolStatus(poolId, 4, 1000e20, 20833333, 316666);

        params.tradeAmount = -980e20;
        assertMatching(params, 980e20, 199970e8, 195971435e18);
        assertPoolStatus(poolId, 1, 20e20, 416666, 41666);

        params.tradeAmount = -20e20;
        assertMatching(params, 20e20, 199988e8, 3999772e18);
        assertPoolStatus(poolId, 0, 0, 0, 0);
    }

    function assertPrice(bytes32 pId, int256 indexPrice, int256 p) public view {
        int256 price = me.getMarketPrice(pId, indexPrice);
        vm.assertGt(price, p);
        vm.assertLe(price, p+1e8);
    }

    function assertTickConfig(bytes32 pId, IMatchingEngine.TickConfig[] memory c1) public view {
        IMatchingEngine.TickAmount[] memory c2 = me.getPoolConf(pId);
        vm.assertEq(c1.length, c2.length, "TCL");
        for (uint256 index = 0; index < c1.length; index++) {
            vm.assertEq(c1[index].usageRatio, c2[index].usageRatio, "TCS");
            vm.assertEq(c1[index].slippage, c2[index].slippage, "TCS");
        }
    }


    function assertPoolStatus(bytes32 pId, uint256 currentTick, int256 position, int256 usageRatio, int256 slippage) public view {
        IMatchingEngine.PoolStatus memory status = me.getStatus(pId);
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