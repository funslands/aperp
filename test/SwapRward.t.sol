// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./Init.sol";


/// test swapReward
contract SwapRewardTest is Init {
    function setUp() public {
        initial();

        pools.addPlugin(a1);
        pools.addPlugin(a2);
        markets.addPlugin(address(this));
        markets.addPlugin(a1);
        markets.addPlugin(a2);

        markets.approve(address(this), true);
        vm.startPrank(a1);
        pools.approve(a1, true);
        markets.approve(a1, true);
        vm.stopPrank();
        vm.startPrank(a2);
        pools.approve(a2, true);
        markets.approve(a2, true);
        vm.stopPrank();
    }
    
    function testSwapUSDReward() public {
        uint256 t = 1740873600;
        vm.warp(t+7200); 
        setPrices(101e6, 2010e8, 80000e8);

        usd.mint(a2, 100000e6);
        vm.deal(a1, 101e18);
        vm.startPrank(a1);
        eth.deposit{value: 100e18}();
        eth.approve(address(pools), 1e18);
        vm.assertEq(eth.balanceOf(a1), 100e18);
        vm.stopPrank();

        vm.startPrank(a2);
        usd.approve(address(markets), 1e18);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: usdPoolId,
            taker: a2,
            direction: true,
            margin: 20000e6,
            amount: 1e20
        }));

        markets.decreasePosition(usdPoolId, a2, true, 1e20);
        vm.stopPrank();


        vm.startPrank(a1);
        vm.expectRevert(IPools.SwapPaused.selector);
        (uint256 input, uint256 output) = pools.swapReward(address(usd));
        
        vm.warp(t + 1 days + 360); 
        setPrices(101e6, 2020e8, 80000e8);
        
        (input, output) = pools.swapReward(address(usd));
        vm.assertEq(input, 16308134452105200);
        vm.assertEq(output, 32678357);
        vm.assertEq(usd.balanceOf(a1), 32678357);
        vm.assertEq(eth.balanceOf(a1), 100e18-16308134452105200);
        vm.assertEq(eth.balanceOf(address(staker)), 16308134452105200);
        

        vm.stopPrank();
    }

    function testSwapBTCReward() public {
        uint256 t = 1740873600;
        vm.warp(t+7200); 
        setPrices(101e6, 2010e8, 80000e8);

        btc.mint(a2, 1e9);
        vm.startPrank(a2);
        btc.approve(address(markets), 1e18);
        vm.stopPrank();
        vm.deal(a1, 101e18);
        vm.startPrank(a1);
        eth.deposit{value: 100e18}();
        eth.approve(address(pools), 1e18);
        vm.assertEq(eth.balanceOf(a1), 100e18);
        vm.stopPrank();

        vm.startPrank(a2);
        usd.approve(address(markets), 1e18);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: true,
            margin: 5e8,
            amount: 5e20
        }));
        markets.decreasePosition(btcPoolId, a2, true, 5e20);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: btcPoolId,
            taker: a2,
            direction: true,
            margin: 5e8,
            amount: 5e20
        }));
        markets.decreasePosition(btcPoolId, a2, true, 5e20);
        vm.stopPrank();


        vm.startPrank(a1);
        vm.expectRevert(IPools.SwapPaused.selector);
        (uint256 input, uint256 output) = pools.swapReward(address(usd));
        
        vm.warp(t + 1 days + 1600); 
        setPrices(101e6, 2050e8, 80400e8);
        
        (input, output) = pools.swapReward(address(usd));
        vm.assertEq(input, 0);
        vm.assertEq(output, 0);

        (input, output) = pools.swapReward(address(btc));
        vm.assertEq(input, 31794698064285965);
        vm.assertEq(output, 814759);
        vm.assertEq(btc.balanceOf(a1), 814759);
        vm.assertEq(eth.balanceOf(a1), 100e18-31794698064285965);
        vm.assertEq(eth.balanceOf(address(staker)), 31794698064285965);
        

        vm.stopPrank();
    }

    function testSwapETHReward() public {
        uint256 t = 1740873600;
        vm.warp(t+7200); 
        setPrices(101e6, 2010e8, 80000e8);

        vm.deal(a2, 10e18);
        vm.startPrank(a2);
        eth.deposit{value: 10e18}();
        eth.approve(address(markets), 10e18);
        eth.approve(address(pools), 10e18);
        vm.stopPrank();

        vm.deal(a1, 101e18);
        vm.startPrank(a1);
        eth.deposit{value: 100e18}();
        eth.approve(address(pools), 1e18);
        eth.approve(address(markets), 1e18);
        vm.assertEq(eth.balanceOf(a1), 100e18);
        vm.stopPrank();

        vm.startPrank(a2);
        eth.approve(address(pools), 1e20);
        pools.addLiquidity(ethPoolId, a2, 5e18, 50e20);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: ethPoolId,
            taker: a2,
            direction: true,
            margin: 4e18,
            amount: 20e20
        }));
        markets.decreasePosition(ethPoolId, a2, true, 20e20);
        markets.increasePosition(IMarkets.IncreasePositionParams({
            marketId: ethPoolId,
            taker: a2,
            direction: true,
            margin: 4e18,
            amount: 20e20
        }));
        markets.decreasePosition(ethPoolId, a2, true, 20e20);
        vm.stopPrank();


        vm.startPrank(a1);
        vm.expectRevert(IPools.SwapPaused.selector);
        (uint256 input, uint256 output) = pools.swapReward(address(eth));
        
        vm.warp(t + 1 days + 2300); 
        setPrices(101e6, 102050e8, 80400e8);

        (input, output) = pools.swapReward(address(eth));
        vm.assertEq(input, 0);
        vm.assertEq(output, 219316622934690);
        vm.assertEq(eth.balanceOf(a1), 100e18+219316622934690);
        vm.assertEq(eth.balanceOf(address(staker)), 32272034922945310);
        

        vm.stopPrank();
    }

    function setPrices(int256 usdPrice, int256 ethPrice, int256 btcPrice) public {
        setPrice(usdId, usdPrice);
        setPrice(ethId, ethPrice);
        setPrice(btcId, btcPrice);
    }
}