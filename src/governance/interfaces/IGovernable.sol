// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IGovernable {
    struct ExecuteInfo {
        address[] addr;
        uint256[] value;
        bytes[] data;
    }

    struct ExecuteResult {
        bool success;
        bytes result;
    }

    struct Vote {
        address proposalor;
        // 0:voting 
        // 1:favor  favor>against
        // 2:against  favor<against
        // 3:hostile  against>totalSupply*70%
        uint8 status; 
        string describe;
        ExecuteInfo executeInfo;
        uint256 endTime;
        uint256 totalSupply;
        uint256 favor;
        uint256 against;
        uint256 reward;
    }

    error OnlyManager();
    error Voting(uint256 id);
    error InvalidId();
    error InvalidEndTime();
    error InvalidExecuteInfo();
    error InsufficientBalance();
    error Ended();
    error IsVoted();
    error NotEnd();
    error IsExecuted();
    error IsClaimed();

    event Proposaled(address indexed proposalor, uint256 indexed id, uint256 endTime, string describe, ExecuteInfo executeInfo);
    event Voted(address indexed account, uint256 indexed id, bool favor, uint256 amount);
    event Executed(uint256 indexed id, address executor, uint8 status, uint256 totalSupply, uint256 favor, uint256 against);
    event Claimed(address indexed account, uint256 indexed id, uint256 reward);

    function staker() external view returns(address);
    function rewardToken() external view returns(address);

    function proposal(
        uint256 endTime,
        string calldata describe,
        ExecuteInfo calldata executeInfo
    ) external returns(uint256 id);
    function vote(uint256 id, bool favor) external;
    function execute(uint256 id) external;
    function claim(uint256 id) external returns(uint256 reward);
}