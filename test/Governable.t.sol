// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

/// test staker

import "forge-std/Test.sol";
import "../src/staking/Staker.sol";
import "../src/governance/Governable.sol";
import "../src/test/TestToken.sol";

contract GovernableTest is Test {
    Staker public staker;
    Governable public gov;
    TestToken public WETH;
    TestToken public token;
    address public user1 = vm.addr(0xabcdef0001);
    address public user2 = vm.addr(0xabcdef0002);
    address public user3 = vm.addr(0xabcdef0003);
    address public user4 = vm.addr(0xabcdef0004);
    address[] public users;
    uint256 current = 1750000000;

    function setUp() public {
        vm.warp(current);

        token = new TestToken("aperp", "APERP", 18);
        WETH = new TestToken("warped ETH", "WETH", 18);
        gov = new Governable(address(token));
        staker = new Staker(address(WETH), address(token), address(gov), "stake APERP", "sAPERP");
        gov.setStaker(address(staker));
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(user3, "User3");
        vm.label(user4, "User4");
        vm.label(address(token), "Token");
        vm.label(address(WETH), "WETH");

        for (uint256 i=0; i<100; i++) {
            address user = vm.addr(0xaaaaaaaaaff0001+i);
            users.push(user);
            token.mint(user, 5000e18);
            vm.startPrank(user);
            token.approve(address(staker), 5000e18);
            staker.stake(5000e18);
            vm.stopPrank();
        }

        token.mint(user1, 100000e18);
        token.mint(user3, 3300e18);
        token.mint(user2, 1e17);
        token.mint(user4, 100000e18);
        token.mint(address(gov), 5000000e18);

        vm.startPrank(user1);
        token.approve(address(staker), 100000e18);
        staker.stake(100000e18);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(staker), 100000e18);
        staker.stake(1e17);
        vm.stopPrank();

        vm.startPrank(user3);
        token.approve(address(staker), 100000e18);
        staker.stake(3300e18);
        vm.stopPrank();

        vm.startPrank(user4);
        token.approve(address(staker), 100000e18);
        staker.stake(100000e18);
        vm.stopPrank();

        vm.warp(current + 11 days);

        for (uint256 i=1; i<103; i++) {
            staker.claimStakedToken(i);
        }
        
        vm.assertEq(staker.balanceOf(user1), 100000e18);
        vm.assertEq(staker.balanceOf(user2), 1e17);
        vm.assertEq(staker.balanceOf(user3), 0);

        for(uint256 i=0; i<100; i++) {
            vm.assertEq(staker.balanceOf(users[i]), 5000e18);
        }
    }

    function testFlow() public {
        IGovernable.ExecuteInfo memory executeInfo;
        executeInfo.addr = new address[](3);
        executeInfo.value = new uint256[](3);
        executeInfo.data = new bytes[](3);
        vm.expectRevert(IGovernable.InvalidEndTime.selector);
        gov.proposal(current+13 days, "invalid end time", executeInfo);
        vm.expectRevert(IGovernable.InvalidEndTime.selector);
        gov.proposal(current+33 days, "invalid end time", executeInfo);

        executeInfo.data = new bytes[](2);
        vm.expectRevert(IGovernable.InvalidExecuteInfo.selector);
        gov.proposal(current+20 days, "invalid execute info", executeInfo);

        executeInfo.data = new bytes[](3);
        executeInfo.value = new uint256[](1);
        vm.expectRevert(IGovernable.InvalidExecuteInfo.selector);
        gov.proposal(current+20 days, "invalid execute info", executeInfo);

        executeInfo.value = new uint256[](3);
        vm.expectRevert(IGovernable.InsufficientBalance.selector);
        gov.proposal(current+20 days, "invalid insufficient balance", executeInfo);

        vm.startPrank(user2);
        vm.expectRevert(IGovernable.InsufficientBalance.selector);
        gov.proposal(current+20 days, "invalid insufficient balance", executeInfo);
        vm.stopPrank();

        // proposal
        vm.startPrank(user1);
        vm.expectEmit(address(gov));
        emit IGovernable.Proposaled(user1, 1, current + 21 days, "AIP 1", executeInfo);
        uint256 res = gov.proposal(current + 21 days, "AIP 1", executeInfo);
        vm.assertEq(res, 1);
        assertVoteInfo(1, user1, "AIP 1", current + 21 days, 0, 0, 0, 0, new bytes(0));
        assertEq(staker.votings(user1), 1);

        vm.expectRevert(abi.encodeWithSelector(IGovernable.Voting.selector, 1));
        gov.proposal(current + 21 days, "AIP 2", executeInfo);
        vm.stopPrank();

        vm.startPrank(user4);
        staker.claimStakedToken(104);
        vm.expectEmit(address(gov));
        emit IGovernable.Proposaled(user4, 2, current + 23 days, "AIP 2", executeInfo);
        res = gov.proposal(current + 23 days, "AIP 2", executeInfo);
        vm.assertEq(res, 2);
        assertVoteInfo(2, user4, "AIP 2", current + 23 days, 0, 0, 0, 0, new bytes(0));
        assertEq(staker.votings(user4), 2);

        vm.expectRevert(abi.encodeWithSelector(IGovernable.Voting.selector, 2));
        res = gov.proposal(current + 21 days, "AIP 2", executeInfo);
        vm.stopPrank();

        // voting
        vm.expectRevert(IGovernable.InvalidId.selector);
        gov.vote(0, true);
        vm.expectRevert(IGovernable.InvalidId.selector);
        gov.vote(0, false);

        vm.startPrank(user2);
        vm.expectRevert(IGovernable.InsufficientBalance.selector);
        gov.vote(1, true);
        vm.expectRevert(IGovernable.InsufficientBalance.selector);
        gov.vote(2, false);

        vm.expectRevert(IGovernable.InsufficientBalance.selector);
        gov.vote(1, true);
        vm.expectRevert(IGovernable.InsufficientBalance.selector);
        gov.vote(2, false);
        vm.stopPrank();


        // aip 1 
        vm.startPrank(user4);
        vm.expectEmit(address(gov));
        emit IGovernable.Voted(user4, 1, true, 10000e18);
        gov.vote(1, true);
        vm.assertEq(gov.accouteVoted(user4, 1), 10000e18);
        assertVoteInfo(1, user1, "AIP 1", current + 21 days, 10000e18, 0, 0, 0, "");

        vm.expectRevert(IGovernable.InvalidId.selector);
        gov.vote(3, true);

        vm.expectRevert(IGovernable.IsVoted.selector);
        gov.vote(1, true);
        vm.expectRevert(IGovernable.IsVoted.selector);
        gov.vote(2, true);
        vm.stopPrank(); 

        staker.claimStakedToken(103);
        vm.startPrank(user3);
        vm.expectEmit(address(gov));
        emit IGovernable.Voted(user3, 1, true, 3300e18);
        gov.vote(1, true);
        assertVoteInfo(1, user1, "AIP 1", current + 21 days, 13300e18, 0, 0, 0, "");
        vm.assertEq(gov.accouteVoted(user3, 1), 3300e18);

        vm.expectEmit(address(gov));
        emit IGovernable.Voted(user3, 2, false, 3300e18);
        gov.vote(2, false);
        assertVoteInfo(2, user4, "AIP 2", current + 23 days, 0, 3300e18, 0, 0, "");
        vm.assertEq(gov.accouteVoted(user3, 2), -3300e18);

        vm.expectRevert(IGovernable.IsVoted.selector);
        gov.vote(1, true);
        vm.expectRevert(IGovernable.IsVoted.selector);
        gov.vote(2, true);
        vm.stopPrank();

        vm.warp(current + 22 days);
        vm.startPrank(users[0]);
        vm.expectRevert(IGovernable.Ended.selector);
        gov.vote(1, false);
        vm.stopPrank();

        // exec aip 1
        vm.expectEmit(address(gov));
        emit IGovernable.Executed(1, address(this), 2, 7033001e17, 13300e18, 0);
        gov.execute(1);
        assertVoteInfo(1, user1, "AIP 1", current + 21 days, 13300e18, 0, 2, 7033001e17, new bytes(0));
        vm.assertEq(token.balanceOf(address(this)), 50e18);
        vm.expectRevert(IGovernable.IsExecuted.selector);
        gov.execute(1);
        vm.expectRevert(IGovernable.NotEnd.selector);
        gov.execute(2);

        // claim aip 1
        vm.startPrank(user1);
        vm.expectEmit(address(gov));
        emit IGovernable.Claimed(user1, 1, 50e18);
        res = gov.claim(1);
        vm.assertEq(res, 50e18);
        vm.assertEq(gov.claimed(user1, 1), true);
        vm.stopPrank();

        vm.startPrank(user3);
        vm.expectEmit(address(gov));
        emit IGovernable.Claimed(user3, 1, 235714285714285714285);
        res = gov.claim(1);
        vm.assertEq(res, 235714285714285714285);
        vm.assertEq(gov.claimed(user3, 1), true);
        vm.stopPrank();

        vm.startPrank(user4);
        vm.expectEmit(address(gov));
        emit IGovernable.Claimed(user4, 1, 714285714285714285714);
        res = gov.claim(1);
        vm.assertEq(res, 714285714285714285714);
        vm.assertEq(gov.claimed(user4, 1), true);
        vm.stopPrank();

        // vote aip 2
        for (uint256 i=0; i<50; i++) {
            vm.startPrank(users[i]);
            if (i%3 == 0) gov.vote(2, true);
            else gov.vote(2, false);
            vm.stopPrank();
        }
        assertVoteInfo(2, user4, "AIP 2", current + 23 days, 85000e18, 168300e18, 0, 0, "");
        
        vm.startPrank(user1);
        gov.vote(2, false);
        vm.assertEq(gov.accouteVoted(user1, 2), -10000e18);
        vm.stopPrank();

        // execute aip 2
        vm.expectRevert(IGovernable.NotEnd.selector);
        gov.execute(2);

        vm.warp(current + 24 days);
        vm.expectEmit(address(gov));
        emit IGovernable.Executed(2, address(this), 2, 7033001e17, 85000e18, 178300e18);
        gov.execute(2);
        vm.assertEq(token.balanceOf(address(this)), 100e18);

        // claim aip 2
        vm.startPrank(user1);
        res = gov.claim(2);
        vm.assertEq(res, 36080516521078617546);
        vm.stopPrank();

        vm.startPrank(user3);
        res = gov.claim(2);
        vm.assertEq(res, 11906570451955943790);
        vm.stopPrank();

        vm.startPrank(user4);
        res = gov.claim(2);
        vm.assertEq(res, 50e18);
        vm.stopPrank();

        for(uint256 i=0; i<50; i++) {
            vm.startPrank(users[i]);
            res = gov.claim(2);
            vm.assertEq(res, 18040258260539308773);
            vm.stopPrank();
        }
        

        // aip 3
        vm.startPrank(user4);
        executeInfo.addr = new address[](1);
        executeInfo.addr[0] = address(staker);
        executeInfo.value = new uint256[](1);
        executeInfo.value[0] = 0;
        executeInfo.data = new bytes[](1);
        executeInfo.data[0] = abi.encodeWithSelector(staker.updateConfig.selector, 9 days, 4 days, address(gov));
        res = gov.proposal(current + 30 days, "update staker config", executeInfo);
        vm.assertEq(res, 3);
        vm.stopPrank();

        // vote
        vm.startPrank(user1);
        gov.vote(3, false);
        vm.stopPrank();

        for(uint256 i=0; i<60; i++) {
            vm.startPrank(users[i]);
            gov.vote(3, true);
            vm.stopPrank();
        }
        assertVoteInfo(3, user4, "update staker config", current + 30 days, 300000e18, 10000e18, 0, 0, abi.encode(executeInfo));

        // execute aip 3
        vm.warp(current + 31 days);
        gov.execute(3);
        assertVoteInfo(3, user4, "update staker config", current + 30 days, 300000e18, 10000e18, 1, 7033001e17, abi.encode(executeInfo));
        vm.assertEq(staker.stakeLockTime(), 9 days);
        vm.assertEq(staker.unstakeLockTime(), 4 days);

        // aip 4
        vm.startPrank(user1);
        executeInfo.addr = new address[](2);
        executeInfo.addr[0] = address(staker);
        executeInfo.addr[1] = address(token);
        executeInfo.value = new uint256[](2);
        executeInfo.value[0] = 0;
        executeInfo.value[1] = 0;
        executeInfo.data = new bytes[](2);
        executeInfo.data[0] = abi.encodeWithSelector(staker.updateConfig.selector, 10 days, 3 days, address(gov));
        executeInfo.data[1] = abi.encodeWithSelector(staker.updateConfig.selector, 9 days, 4 days, address(gov));
        res = gov.proposal(current + 37 days, "exec fail", executeInfo);
        vm.assertEq(res, 4);
        vm.stopPrank();

        // vote
        vm.startPrank(user4);
        gov.vote(4, true);
        vm.stopPrank();

        for(uint256 i=0; i<60; i++) {
            vm.startPrank(users[i]);
            gov.vote(4, true);
            vm.stopPrank();
        }
        assertVoteInfo(4, user1, "exec fail", current + 37 days, 310000e18, 0, 0, 0, abi.encode(executeInfo));

        // execute aip 4
        vm.warp(current + 38 days);
        gov.execute(4);
        assertVoteInfo(4, user1, "exec fail", current + 37 days, 310000e18, 0, 1, 7033001e17, abi.encode(executeInfo));
        vm.assertEq(staker.stakeLockTime(), 10 days);
        vm.assertEq(staker.unstakeLockTime(), 3 days);

        // aip 5
        vm.startPrank(user1);
        executeInfo.addr = new address[](2);
        executeInfo.addr[0] = address(staker);
        executeInfo.value = new uint256[](2);
        executeInfo.value[0] = 0;
        executeInfo.data = new bytes[](2);
        executeInfo.data[0] = abi.encodeWithSelector(staker.updateConfig.selector, 10 days, 3 days, address(gov));
        res = gov.proposal(current + 50 days, "penalty", executeInfo);
        vm.assertEq(res, 5);
        vm.stopPrank();

        // vote
        vm.startPrank(user4);
        gov.vote(5, true);
        vm.stopPrank();

        for(uint256 i=0; i<99; i++) {
            vm.startPrank(users[i]);
            gov.vote(5, false);
            vm.stopPrank();
        }
        assertVoteInfo(5, user1, "penalty", current + 50 days, 10000e18, 495000e18, 0, 0, abi.encode(executeInfo));

        // execute aip 5
        vm.warp(current + 50 days + 10);
        gov.execute(5);
        assertVoteInfo(5, user1, "penalty", current + 50 days, 10000e18, 495000e18, 3, 7033001e17, abi.encode(executeInfo));
        vm.assertEq(staker.balanceOf(user1), 0);
        vm.assertEq(staker.staked(user1), 0);
        
        vm.startPrank(user1);
        res = gov.claim(5);
        vm.assertEq(res, 0);
        vm.stopPrank();

        vm.startPrank(user4);
        res = gov.claim(5);
        vm.assertEq(res, 1980198019801980198019);
        vm.stopPrank();

        for(uint256 i=0; i<100; i++) {
            vm.startPrank(users[i]);
            res = gov.claim(5);
            if (i<99)
                vm.assertEq(res, 990099009900990099009);
            else
                vm.assertEq(res, 0);
            vm.stopPrank();
        }
    }

    function assertVoteInfo(
        uint256 id, 
        address proposalor, 
        string memory describe, 
        uint256 endTime,
        uint256 favor,
        uint256 against,
        uint8 status,
        uint256 totalSupply,
        bytes memory executeInfo
    ) public view {
        IGovernable.Vote memory info = gov.getVoteInfo(id);
        vm.assertEq(info.proposalor, proposalor, "EPR");
        vm.assertEq(info.describe, describe, "ED");
        vm.assertEq(info.endTime, endTime, "EDT");
        vm.assertEq(info.favor, favor, "EF");
        vm.assertEq(info.against, against, "EA");
        vm.assertEq(info.status, status, "ES");
        if (executeInfo.length > 0) vm.assertEq(abi.encode(info.executeInfo), executeInfo, "EEI");
        vm.assertEq(info.totalSupply, totalSupply, "ETS");
    }
}