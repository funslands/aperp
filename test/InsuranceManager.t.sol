// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Test.sol";
import "../src/core/InsuranceManager.sol";
import "../src/test/TestToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InsuranceManagerTest is Test {
    address public a1 = vm.addr(0xff323);
    address public a2 = vm.addr(0xff322);
    address public pools = vm.addr(0xf0321);

    InsuranceManager public im;
    address public btc;
    address public usd;
    address public tst;

    bytes32 btcPool;
    bytes32 usdPool;
    bytes32 tstPool;

    
    function setUp() public {
        im = new InsuranceManager(pools);
        btc = address(new TestToken("warp BTC", "wBTC", 9));
        usd = address(new TestToken("usd", "USD", 6));
        tst = address(new TestToken("test", "TST", 18));
        btcPool = keccak256(abi.encode(btc));
        usdPool = keccak256(abi.encode(usd));
        tstPool = keccak256(abi.encode(tst));

        vm.startPrank(pools);
        im.updatePoolConfig(btcPool, btc, 1e6);
        im.updatePoolConfig(tstPool, tst, 5e18);
        im.updatePoolConfig(usdPool, usd, 5e6);
        vm.stopPrank();
    }

    function testSetPools() public {
        vm.startPrank(a2);
        vm.expectRevert(Governable.notGov.selector);
        im.setGov(a1);
        vm.stopPrank();
        
        vm.assertEq(im.gov(), address(this));

        im.setGov(a2);
        vm.assertEq(im.gov(), a2);
        vm.expectRevert(Governable.notGov.selector);
        im.setGov(a1);
    }

    function testUpdatePoolConfig() public {
        address doge = address(new TestToken("doge", "DOGE", 9));
        address usdc = address(new TestToken("usdc", "USDC", 6));
        bytes32 dogePool = keccak256(abi.encode(doge));
        bytes32 usdcPool = keccak256(abi.encode(usdc));

        vm.startPrank(a1);
        vm.expectRevert(IInsuranceManager.InvalidCall.selector);
        im.updatePoolConfig(dogePool, doge, 1e6);
        vm.expectRevert(IInsuranceManager.InvalidCall.selector);
        im.updatePoolConfig(usdcPool, usdc, 5e18);
        vm.stopPrank();

        vm.startPrank(pools);
        im.updatePoolConfig(usdcPool, usdc, 5e6);
        vm.expectEmit(address(im));
        emit IInsuranceManager.UpdatedPoolConfig(usdcPool, usdc, 5e6);
        im.updatePoolConfig(usdcPool, usdc, 5e6);
        vm.stopPrank();

        im.updatePoolConfig(dogePool, doge, 1e6);
        vm.expectEmit(address(im));
        emit IInsuranceManager.UpdatedPoolConfig(dogePool, doge, 1e6);
        im.updatePoolConfig(dogePool, doge, 1e6);
        
        vm.assertEq(im.poolToken(dogePool), doge);
        vm.assertEq(im.poolToken(usdcPool), usdc);
        vm.assertEq(im.rewardAmount(dogePool), 1e6);
        vm.assertEq(im.rewardAmount(usdcPool), 5e6);
    }

    function testAddInsurance() public {
        vm.expectRevert(IInsuranceManager.OnlyPools.selector);
        im.addInsurance(btcPool, 1e7);

        TestToken(address(usd)).mint(pools, 1e14);
        vm.startPrank(pools);
        vm.expectRevert(IInsuranceManager.InvalidAmount.selector);
        im.addInsurance(usdPool, 1e8);

        IERC20(usd).transfer(address(im), 2e8);
        vm.expectRevert(IInsuranceManager.InvalidAmount.selector);
        im.addInsurance(usdPool, 2e8+1);
        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceAdded(usdPool, 2e8);
        im.addInsurance(usdPool, 2e8);
        vm.stopPrank();

        vm.assertEq(im.poolBalances(usdPool), 2e8);
        vm.assertEq(im.assetBalances(usd), 2e8);

        TestToken(tst).mint(pools, 1e26);
        vm.startPrank(pools);
        TestToken(tst).transfer(address(im), 3e20);
        im.addInsurance(tstPool, 1e20);
        vm.stopPrank();

        vm.assertEq(im.poolBalances(tstPool), 1e20);
        vm.assertEq(im.assetBalances(tst), 3e20);

        bytes32 usd2Pool = bytes32(uint256(uint160(usd)));
        im.updatePoolConfig(usd2Pool, usd, 5e6);
        vm.startPrank(pools);
        TestToken(usd).transfer(address(im), 3e7);
        im.addInsurance(usd2Pool, 3e7);
        vm.stopPrank();
        vm.assertEq(im.poolBalances(usd2Pool), 3e7);
        vm.assertEq(im.assetBalances(usd), 2e8+3e7);
    }

    function testDonate() public {
        TestToken(usd).mint(address(this), 1e10);
        TestToken(usd).approve(address(im), 1e8);

        im.donate(usdPool, 5e7);

        vm.assertEq(im.poolBalances(usdPool), 5e7);
        vm.assertEq(im.assetBalances(usd), 5e7);

        vm.assertEq(
            TestToken(usd).balanceOf(address(this)),
            1e10-5e7    
        );
    }

    function testInsuranceOperate() public {
        TestToken(tst).mint(address(this), 1e22);
        TestToken(tst).approve(address(im), 1e22);
        im.donate(tstPool, 1e20);

        TestToken(tst).transfer(address(im), 5e20);
        vm.startPrank(pools);
        im.addInsurance(tstPool, 5e20);

        vm.assertEq(im.poolBalances(tstPool), 6e20);
        
        vm.expectRevert(IInsuranceManager.InsufficientBalance.selector);
        im.useInsurance(tstPool, 6e20+1);
        

        vm.expectEmit(address(im));
        emit IInsuranceManager.InsuranceUsed(tstPool, 3e20);
        im.useInsurance(tstPool, 3e20);
        vm.stopPrank();

        vm.assertEq(im.poolBalances(tstPool), 3e20);
        vm.assertEq(TestToken(tst).balanceOf(pools), 3e20);

        
        vm.expectRevert(IInsuranceManager.OnlyPools.selector);
        im.liquidatorReward(tstPool, a2);

        vm.startPrank(pools);
        vm.expectEmit(address(im));
        emit IInsuranceManager.LiquidatorReward(tstPool, a2, 5e18);
        im.liquidatorReward(tstPool, a2);
        vm.stopPrank();

        vm.assertEq(im.userBalances(a2, tst), 5e18);
        vm.assertEq(im.poolBalances(tstPool), 3e20);
        vm.assertEq(im.assetBalances(tst), 3e20);

        vm.startPrank(a2);
        vm.expectRevert(IInsuranceManager.InsufficientBalance.selector);
        im.withdrawReward(a1, tst, 5e18+1);

        vm.expectEmit(address(im));
        emit IInsuranceManager.WithdrawReward(tst, a1, 4e18);
        im.withdrawReward(a1, tst, 4e18);
        vm.stopPrank();

        vm.assertEq(TestToken(tst).balanceOf(a1), 4e18);
        vm.assertEq(im.userBalances(a2, tst), 1e18);
        vm.assertEq(im.assetBalances(tst), 3e20-4e18);
        vm.assertEq(TestToken(tst).balanceOf(address(im)), 3e20-4e18);

        vm.startPrank(pools);
        vm.expectRevert(Governable.notGov.selector);
        im.withdrawInsurance(tstPool, a1, 3e18);
        vm.stopPrank();
        vm.expectEmit(address(im));
        emit IInsuranceManager.WithdrawInsurance(tstPool, a1, 3e18);
        im.withdrawInsurance(tstPool, a1, 3e18);
        vm.assertEq(TestToken(tst).balanceOf(a1), 7e18);
        vm.assertEq(im.assetBalances(tst), 3e20-7e18);
        vm.assertEq(TestToken(tst).balanceOf(address(im)), 3e20-7e18);
        vm.assertEq(im.poolBalances(tstPool), 3e20-3e18);

    }
}