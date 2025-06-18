// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

/// test staker

import "forge-std/Test.sol";
import "../src/staking/Staker.sol";
import "../src/test/TestToken.sol";

contract StakerTest is Test {
    Staker public staker;
    TestToken public WETH;
    TestToken public token;
    address public gov = vm.addr(0xfff00001);
    address public user1 = vm.addr(0xabcdef0001);
    address public user2 = vm.addr(0xabcdef0002);
    uint256 current = 1750000000;

    function setUp() public {
        vm.warp(current);

        token = new TestToken("aperp", "APERP", 18);
        WETH = new TestToken("warped ETH", "WETH", 18);
        staker = new Staker(address(WETH), address(token), gov, "stake APERP", "sAPERP");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(gov, "Gov");
        vm.label(address(token), "Token");
        vm.label(address(WETH), "WETH");
    }

    function testUpdateConfig() public {
        vm.assertEq(staker.gov(), gov);
        vm.assertEq(staker.stakeToken(), address(token));
        vm.assertEq(staker.name(), "stake APERP");
        vm.assertEq(staker.symbol(), "sAPERP");
        vm.assertEq(staker.stakeLockTime(), 10 days);
        vm.assertEq(staker.unstakeLockTime(), 3 days);

        vm.expectRevert(IStaker.NotGov.selector);
        staker.updateConfig(7 days, 1 days, user1);

        vm.startPrank(user2);
        vm.expectRevert(IStaker.NotGov.selector);
        staker.updateConfig(7 days, 1 days, user1);
        vm.stopPrank();

        vm.startPrank(gov);
        vm.expectRevert(IStaker.InvalidStakeLockTime.selector);
        staker.updateConfig(1 days, 1 days, user1);
        vm.expectRevert(IStaker.InvalidStakeLockTime.selector);
        staker.updateConfig(31 days, 1 days, user1);

        vm.expectRevert(IStaker.InvalidUnstakeLockTime.selector);
        staker.updateConfig(7 days, 11 days, user1);

        vm.expectEmit(address(staker));
        emit IStaker.UpdatedConfig(7 days, 5 days, user2);
        staker.updateConfig(7 days, 5 days, user2);
        vm.stopPrank();
    }

    function testFlow() public {
        // init
        WETH.mint(address(this), 10 ether);
        WETH.approve(address(staker), 10 ether);

        vm.startPrank(user1);
        WETH.mint(user1, 10 ether);
        WETH.approve(address(staker), 10 ether);

        token.mint(user1, 100000 ether);
        token.approve(address(staker), 100000 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        WETH.mint(user2, 10 ether);
        WETH.approve(address(staker), 10 ether);

        token.mint(user2, 100000 ether);
        token.approve(address(staker), 100000 ether);
        vm.stopPrank();

        // stake
        vm.expectEmit(address(staker));
        emit IStaker.AddedReward(address(this), 1e16+43577892);
        staker.addReward(1e16+43577892);
        vm.assertEq(staker.remain(), (1e16+43577892)*1e20);

        vm.startPrank(user1);
        vm.expectEmit(address(staker));
        emit IStaker.Staked(user1, 1, 1120e18, current + 10 days);
        staker.stake(1120e18);
        assertBalance(user1, 1120e18, 0, 1120e18, 0);
        assertLockInfo(1, true, user1, 1120e18, false, current + 10 days);
        vm.stopPrank();

        vm.warp(current + 1 days);
        vm.startPrank(user2);
        vm.expectEmit(address(staker));
        emit IStaker.Staked(user2, 2, 100000e18, current + 11 days);
        staker.stake(100000e18);
        assertBalance(user2, 100000e18, 0, 100000e18+1120e18, 0);
        assertLockInfo(2, true, user2, 100000e18, false, current + 11 days);
        vm.stopPrank();

        vm.expectRevert(IStaker.NotBalance.selector);
        staker.unstake(1e18);

        vm.startPrank(user1);
        vm.expectRevert(IStaker.NotBalance.selector);
        staker.unstake(1e18);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(IStaker.NotBalance.selector);
        staker.unstake(1e18);
        vm.stopPrank();

        // reward
        staker.addReward(3e16+77489214);
        vm.startPrank(user1);
        uint256 reward = staker.claimReward();
        vm.assertEq(reward, 443037976024470);
        vm.assertEq(WETH.balanceOf(user1), 10e18+443037976024470);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 getReward = staker.getReward(user2);
        staker.updateReward();
        vm.assertEq(staker.reward(user2), getReward);
        staker.claimReward();
        vm.assertEq(WETH.balanceOf(user2), 10e18+39556962145042000);
        vm.stopPrank();
        
        // claim sToken
        vm.expectRevert(abi.encodeWithSelector(IStaker.Locking.selector, current+10 days));
        staker.claimStakedToken(1);

        vm.warp(current + 10 days + 1);
        vm.expectEmit(address(staker));
        emit IStaker.ClaimStakedToken(user1, 1, 1120e18);
        staker.claimStakedToken(1);
        assertBalance(user1, 1120e18, 1120e18, 1120e18+100000e18, 1120e18);
        assertBalance(user2, 100000e18, 0, 1120e18+100000e18, 1120e18);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(IStaker.Locking.selector, current+11 days));
        staker.claimStakedToken(2);

        vm.warp(current + 11 days + 1);
        emit IStaker.ClaimStakedToken(user2, 2, 100000e18);
        staker.claimStakedToken(2);
        assertBalance(user1, 1120e18, 1120e18, 1120e18+100000e18, 100000e18+1120e18);
        assertBalance(user2, 100000e18, 100000e18, 1120e18+100000e18, 100000e18+1120e18);

        vm.expectRevert(IStaker.Claimed.selector);
        staker.claimStakedToken(2);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(IStaker.Claimed.selector);
        staker.claimStakedToken(1);
        vm.expectRevert(IStaker.Claimed.selector);
        staker.claimStakedToken(2);
        vm.stopPrank();

        // unstake
        vm.startPrank(user1);
        vm.expectEmit(address(staker));
        emit IStaker.Unstaked(user1, 1, 1120e18, current+14 days+1);
        staker.unstake(10000e18);
        assertBalance(user1, 1120e18, 0, 1120e18+100000e18, 100000e18);
        assertLockInfo(1, false, user1, 1120e18, false, current+14 days+1);

        vm.startPrank(user2);
        vm.expectEmit(address(staker));
        emit IStaker.Unstaked(user2, 2, 30000e18, current+14 days+1);
        staker.unstake(30000e18);
        assertBalance(user2, 100000e18, 70000e18, 1120e18+100000e18, 70000e18);
        assertLockInfo(2, false, user2, 30000e18, false, current+14 days+1);
        vm.stopPrank();

        vm.warp(current + 5 days);
        vm.startPrank(gov);
        staker.voting(user2, 1);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(IStaker.Voting.selector, 1));
        staker.unstake(100000e18);
        vm.stopPrank();

        vm.startPrank(gov);
        vm.expectRevert(IStaker.NotVoting.selector);
        staker.penalty(user1);

        vm.expectEmit(address(staker));
        emit IStaker.Penalty(user2, 70000e18);
        staker.penalty(user2);
        assertBalance(user2, 30000e18, 0, 1120e18+30000e18, 0);
        vm.assertEq(token.balanceOf(gov), 70000e18);
        vm.stopPrank();


        
        staker.addReward(1e17);
        uint256 b1 = WETH.balanceOf(user1);
        uint256 b2 = WETH.balanceOf(user2);


        vm.startPrank(user1);
        staker.claimReward();
        vm.stopPrank();
        vm.startPrank(user2);
        staker.claimReward();
        vm.stopPrank();
        vm.assertEq(WETH.balanceOf(user1), b1+3598971722365051);
        vm.assertEq(WETH.balanceOf(user2), b2+96401028277635300);


        vm.warp(current + 15 days);
        assertBalance(user2, 30000e18, 0, 1120e18+30000e18, 0);
        staker.claimStakeToken(2);
        assertBalance(user2, 0, 0, 1120e18, 0);
        assertLockInfo(2, false, user2, 30000e18, true, current+14 days+1);

        staker.claimStakeToken(1);
        assertBalance(user1, 0, 0, 0, 0);
        assertLockInfo(1, false, user1, 1120e18, true, current+14 days+1);
    }

    function assertBalance(address account, uint256 staked, uint256 balance, uint256 totalStaked, uint256 totalSpply) private view {
        vm.assertEq(staker.staked(account), staked, "ES");
        vm.assertEq(staker.balanceOf(account), balance, "EB");
        vm.assertEq(staker.totalStaked(), totalStaked, "ETST");
        vm.assertEq(staker.totalSupply(), totalSpply, "ETSP");
    }

    function assertLockInfo(uint256 id, bool isStake, address account, uint256 amount, bool claimed, uint256 unlockTime) public view {
        IStaker.LockInfo memory info;
        if (isStake) {
            info = staker.getStakeLockInfo(id);
        }
        else {
            info = staker.getUnstakeLockInfo(id);
        }
        
        vm.assertEq(info.account, account, "EACC");
        vm.assertEq(info.amount, amount, "EA");
        vm.assertEq(info.claimed, claimed, "EC");
        vm.assertEq(info.unlockTime, unlockTime, "ELTIME");
    }
}