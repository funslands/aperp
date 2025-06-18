// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IStaker {
    struct LockInfo {
        address account;
        bool claimed;
        uint256 amount;
        uint256 unlockTime;
    }

    error InvalidLockId();
    error Locking(uint256 unlockTime);
    error Claimed();
    error Abandoned();
    error NotGov();
    error Voting(uint256 id);
    error InvalidStakeLockTime();
    error InvalidUnstakeLockTime();
    error NotBalance();
    error NotVoting();

    event UpdatedConfig(uint256 stakeLockTime, uint256 unstakeLockTime, address gov);
    event Staked(address indexed account, uint256 indexed lockId, uint256 amount, uint256 unlockTime);
    event Unstaked(address indexed account, uint256 indexed lockId, uint256 amount, uint256 unlockTime);
    event ClaimedReward(address indexed account, uint256 amount);
    event AddedReward(address adder, uint256 amount);
    event ClaimStakeToken(address indexed account, uint256 indexed lockId, uint256 amount);
    event ClaimStakedToken(address indexed account, uint256 indexed lockId, uint256 amount);
    event Penalty(address indexed account, uint256 amount);

    function stakeToken() external returns(address);
    function stakeLockTime() external returns(uint256);
    function unstakeLockTime() external returns(uint256);
    function totalStaked() external returns(uint256);
    function votings(address account) external returns(uint256 id);

    function staked(address account) external returns(uint256);
    function reward(address account) external returns(uint256);

    function stake(uint256 amount) external;
    function unstake(uint256 amount) external returns(uint256 unsatkedAmount);
    function updateReward() external returns(uint256 newRewardPerToken);
    function claimReward() external returns(uint256 amount);
    function claimStakeToken(uint256 lockId) external returns(uint256 amount);
    function claimStakedToken(uint256 lockId) external returns(uint256 amount);
    function voting(address account, uint256 id) external;
    function voted(address account, uint256 id) external;

    function penalty(address account) external returns(uint256 amount);
    function addReward(uint256 amount) external;
}