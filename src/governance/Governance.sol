// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;
import "./interfaces/IGovernance.sol";
import "../staking/interfaces/IStaker.sol";
import "../libraries/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract Governance is IGovernance, ReentrancyGuard {
    address public manager;
    address public override staker;
    address public override rewardToken;
    uint256 public minVote = 1e18;          // 1
    uint256 public maxVote = 10000e18;      // 10000
    uint256 public proposalNum = 1000e18;   // 1000
    uint256 public initReward = 1000e18;   // 1000
    Vote[] private votes;
    // account=> id => amount
    mapping(address=> mapping(uint256=> int256)) public accouteVoted;
    // account=> id => is claimed
    mapping(address=> mapping(uint256=> bool)) public claimed;
    // id => execute result
    mapping(uint256=> bytes) public executeResult;

    constructor(address _rewardToken) {
        manager = msg.sender;
        rewardToken = _rewardToken;
    }

    function setStaker(address _staker) external {
        require(msg.sender == manager, OnlyManager());
        if (staker == address(0)) staker = _staker;
    }

    function voteNum() public view returns(uint256) {
        return votes.length;
    }

    function getVoteInfo(uint256 id) public view returns(Vote memory) {
        require(id > 0 && id <= votes.length, InvalidId());
        return votes[id-1];
    }

    function decodeExecuteResult(uint256 id) public view returns(ExecuteResult[] memory) {
        require(id > 0 && id <= votes.length, InvalidId());
        return abi.decode(executeResult[id], (ExecuteResult[]));
    }


    function proposal(
        uint256 endTime,
        string calldata describe,
        ExecuteInfo calldata executeInfo
    ) external override returns(uint256 id) {
        require(endTime >= block.timestamp + 5 days && endTime <= block.timestamp + 15 days, InvalidEndTime());
        require(
            executeInfo.addr.length == executeInfo.data.length &&
            executeInfo.addr.length == executeInfo.value.length, 
            InvalidExecuteInfo()
        );
        require(IERC20(staker).balanceOf(msg.sender)>proposalNum, InsufficientBalance());
        uint256 votingId = IStaker(staker).votings(msg.sender);
        require(votingId == 0, Voting(votingId));
        Vote memory info = Vote({
            proposalor: msg.sender,
            status: 0,
            describe: describe,
            executeInfo: executeInfo,
            endTime: endTime,
            totalSupply: 0,
            favor: 0,
            against: 0,
            reward: 0
        });
        votes.push(info);
        id = votes.length;
        IStaker(staker).voting(msg.sender, id);
        emit Proposaled(msg.sender, id, endTime, describe, executeInfo);
    }

    function vote(uint256 id, bool favor) external override {
        require(id > 0, InvalidId());
        Vote memory info = getVoteInfo(id);
        require(block.timestamp < info.endTime, Ended());
        require(accouteVoted[msg.sender][id] == 0, IsVoted());
        require(info.proposalor != msg.sender, IsVoted());
        uint256 balance = IERC20(staker).balanceOf(msg.sender);
        require(balance>=minVote, InsufficientBalance());
        if (balance > maxVote) balance = maxVote;
        if (favor) {
            info.favor += balance;
            accouteVoted[msg.sender][id] = int256(balance);
        }
        else {
            info.against += balance;
            accouteVoted[msg.sender][id] = -int256(balance);
        }
        votes[id-1] = info;

        emit Voted(msg.sender, id, favor, balance);
    }

    function execute(uint256 id) external override nonReentrant() {
        require(id > 0, InvalidId());
        Vote memory info = getVoteInfo(id);
        require(info.status == 0, IsExecuted());
        require(block.timestamp > info.endTime, NotEnd());
        uint256 totalSupply = IERC20(staker).totalSupply();
        uint256 totalVote = info.favor + info.against;
        if (totalVote < 100000e18) info.status = 2;
        else if (info.favor > info.against) info.status = 1;
        else {
            // malicious proposal
            if (info.against*1e8/totalSupply > 7e7) info.status = 3;
            else info.status = 2;
        }

        info.totalSupply = totalSupply;
        // reward halving: 500 proposal
        info.reward = initReward / 2**(id/500);
        uint256 len = info.executeInfo.addr.length;
        bool success;
        bytes memory result;
        ExecuteResult[] memory er = new ExecuteResult[](len);
        if (info.status == 1) {
            for (uint256 i=0; i<len; i++) {
                if (info.executeInfo.value[i] == 0)
                    (success, result) = info.executeInfo.addr[i].call(info.executeInfo.data[i]);
                else
                    (success, result) = info.executeInfo.addr[i].call{value: info.executeInfo.value[i]}(info.executeInfo.data[i]);
                er[i] = (ExecuteResult({
                    success: success,
                    result: result
                }));
            }
        }
        else if (info.status == 3) {
            info.reward = IStaker(staker).penalty(info.proposalor);
        }

        executeResult[id] = abi.encode(er);
        votes[id-1] = info;

        IStaker(staker).voted(info.proposalor, id);

        SafeERC20.safeTransfer(IERC20(rewardToken), msg.sender, 50e18);
        emit Executed(id, msg.sender, info.status, totalSupply, info.favor, info.against);
    }

    function claim(uint256 id) external nonReentrant returns(uint256 reward) {
        require(!claimed[msg.sender][id], IsClaimed());
        Vote memory info = getVoteInfo(id);
        require(info.status != 0, Voting(0));
        if (msg.sender == info.proposalor && info.status != 3) {
            reward = info.reward * 5e6 / 1e8;
        }
        else {
            int256 amount = accouteVoted[msg.sender][id];
            if (amount == 0) return 0;
            uint256 voteAmount = amount > 0 ? uint256(amount) : uint256(-amount);
            if (info.status == 3) {
                reward = info.reward * voteAmount / (info.favor + info.against);
            }
            else {
                reward = (info.reward*95e6/1e8) * voteAmount / (info.favor + info.against);
            }
        }
        
        claimed[msg.sender][id] = true;
        SafeERC20.safeTransfer(IERC20(rewardToken), msg.sender, reward);

        emit Claimed(msg.sender, id, reward);
    }
}