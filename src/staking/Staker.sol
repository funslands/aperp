// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./interfaces/IStaker.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract Staker is IStaker {
    /***** ERC20 info *****/
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address spender => uint256)) public allowance;

    address public WETH;
    address public gov;
    address public override stakeToken;
    uint256 public growthGlobalRewardPerToken;
    uint256 public remain = 0;
    uint256 public override stakeLockTime = 10 days;
    uint256 public override unstakeLockTime = 3 days;
    uint256 public override totalStaked;
    mapping (address=> uint256) public override staked;
    mapping (address=> uint256) public override reward;
    mapping (address=> uint256) public lastRewardPerToken;
    mapping (address=> uint256) public override votings;

    LockInfo[] private stakeLockInfo;
    LockInfo[] private unstakeLockInfo;

    constructor(address _WETH, address _stakeToken, address _gov, string memory _name, string memory _symbol) {
        WETH = _WETH;
        name = _name;
        symbol = _symbol;
        gov = _gov;
        stakeToken = _stakeToken;
    }

    function updateConfig(uint256 _stakeLockTime, uint256 _unstakeLockTime, address _gov) external {
        require(msg.sender == gov, NotGov());
        require(_stakeLockTime >= 7 days && _stakeLockTime <= 30 days, InvalidStakeLockTime());
        require(_unstakeLockTime <= 10 days, InvalidUnstakeLockTime());
        stakeLockTime = _stakeLockTime;
        unstakeLockTime = _unstakeLockTime;
        gov = _gov;

        emit UpdatedConfig(_stakeLockTime, _unstakeLockTime, _gov);
    }

    function stakeLockNum() public view returns(uint256) {
        return stakeLockInfo.length;
    }

    function unstakeLockNum() public view returns(uint256) {
        return unstakeLockInfo.length;
    }

    function getStakeLockInfo(uint256 lockId) public view returns(LockInfo memory) {
        require(lockId > 0 && lockId <= stakeLockInfo.length, InvalidLockId());
        return stakeLockInfo[lockId-1];
    }

    function getUnstakeLockInfo(uint256 lockId) public view returns(LockInfo memory) {
        require(lockId > 0 && lockId <= unstakeLockInfo.length, InvalidLockId());
        return unstakeLockInfo[lockId-1];
    }

    function stake(uint256 amount) public override {
        SafeERC20.safeTransferFrom(IERC20(stakeToken), msg.sender, address(this), amount);
        staked[msg.sender] += amount;
        totalStaked += amount;
        lastRewardPerToken[msg.sender] = updateReward();

        LockInfo memory info = LockInfo({
            account: msg.sender,
            claimed: false,
            amount: amount,
            unlockTime: block.timestamp + stakeLockTime
        });

        stakeLockInfo.push(info);
        emit Staked(msg.sender, stakeLockInfo.length, amount, info.unlockTime);
    }

    function unstake(uint256 amount) public override returns(uint256 unsatkedAmount) {
        uint256 balance = balanceOf[msg.sender];
        require(balance > 0, NotBalance());
        require(votings[msg.sender] == 0, Voting(votings[msg.sender]));
        if (amount > balance) amount = balance;
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        unsatkedAmount = amount;
        LockInfo memory info = LockInfo({
            account: msg.sender,
            claimed: false,
            amount: amount,
            unlockTime: block.timestamp + unstakeLockTime
        });

        unstakeLockInfo.push(info);
        emit Unstaked(msg.sender, unstakeLockInfo.length, amount, info.unlockTime);
    }

    function penalty(address account) public override returns(uint256 amount) {
        require(msg.sender == gov, NotGov());
        require(votings[account] != 0, NotVoting());
        amount = _unstake(account, balanceOf[account]);
        balanceOf[account] = 0;
        totalSupply -= amount;

        SafeERC20.safeTransfer(IERC20(stakeToken), gov, amount);
        emit Penalty(account, amount);
    }

    function getReward(address account) public view returns(uint256 accReward) {
        uint256 ggpt = growthGlobalRewardPerToken;
        if (ggpt == 0) return 0;
        accReward = reward[account];
        uint256 accLasetRewardPerToken = lastRewardPerToken[account];
        if (accLasetRewardPerToken == ggpt) return accReward;
        accReward += (ggpt-accLasetRewardPerToken)*staked[account]/1e20;
    }

    function updateReward() public override returns(uint256 newRewardPerToken) {
        uint256 ggpt = growthGlobalRewardPerToken;
        if (ggpt == 0) return 0;
        uint256 accLasetRewardPerToken = lastRewardPerToken[msg.sender];
        if (accLasetRewardPerToken == ggpt) return accLasetRewardPerToken;
        uint256 accReward = (ggpt-accLasetRewardPerToken)*staked[msg.sender]/1e20;
        reward[msg.sender] += accReward;
        lastRewardPerToken[msg.sender] = ggpt;
        return ggpt;
    }

    function claimReward() public override returns(uint256 amount) {
        updateReward();
        amount = reward[msg.sender];
        SafeERC20.safeTransfer(IERC20(WETH), msg.sender, amount);
        reward[msg.sender] = 0;

        emit ClaimedReward(msg.sender, amount);
    }

    function claimStakedToken(uint256 lockId) public override returns(uint256 amount) {
        require(lockId > 0, InvalidLockId());
        LockInfo memory info = stakeLockInfo[lockId-1];
        require(info.unlockTime < block.timestamp, Locking(info.unlockTime));
        require(!info.claimed, Claimed());
        amount = info.amount;
        balanceOf[info.account] += amount;
        totalSupply += amount;
        info.claimed = true;
        stakeLockInfo[lockId-1] = info;
        emit ClaimStakedToken(info.account, lockId, amount);
    }

    function claimStakeToken(uint256 lockId) public override returns(uint256 amount) {
        require(lockId > 0, InvalidLockId());
        LockInfo memory info = unstakeLockInfo[lockId-1];
        require(info.unlockTime < block.timestamp, Locking(info.unlockTime));
        require(!info.claimed, Claimed());
        _unstake(info.account, info.amount);

        SafeERC20.safeTransfer(IERC20(stakeToken), info.account, info.amount);
        info.claimed = true;
        unstakeLockInfo[lockId-1] = info;
        emit ClaimStakeToken(info.account, lockId, info.amount);
        return info.amount;
    }

    function addReward(uint256 amount) public override {
        SafeERC20.safeTransferFrom(IERC20(WETH), msg.sender, address(this), amount);
        if (totalStaked == 0) {
            remain += amount*1e20;
        }
        else {
            growthGlobalRewardPerToken += (amount*1e20+remain)/totalStaked;
            remain = (amount+remain)*1e20%totalStaked;
        }

        emit AddedReward(msg.sender, amount);
    }

    function voting(address account, uint256 id) public override {
        require(msg.sender == gov, NotGov());
        votings[account] = id;
    }

    function voted(address account, uint256 id) public override {
        require(msg.sender == gov, NotGov());
        if (votings[account] == id) votings[account] = 0;
    }

    function _unstake(address account, uint256 amount) private returns(uint256) {
        updateReward();
        staked[account] -= amount;
        totalStaked -= amount;
        return amount;
    }

    /****** ERC20 function  ******/
    function transfer(address to, uint256 value) public virtual returns (bool) {
        (to, value);
        revert Abandoned();
    }
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        (from, to, value);
        revert Abandoned();
    }
    function approve(address spender, uint256 value) public virtual returns (bool) {
        (spender, value);
        revert Abandoned();
    }
}