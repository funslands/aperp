// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./interfaces/IInsuranceManager.sol";

import "../libraries/Governable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract InsuranceManager is IInsuranceManager, Governable {
    address public pools;
    // poolId => reward amount
    mapping(bytes32 => uint256) public rewardAmount;
    // poolId => token
    mapping(bytes32 => address) public poolToken;
    // token => balance
    mapping(address => uint256) public assetBalances;
    // poolId => balance
    mapping(bytes32 => uint256) public poolBalances;
    // user => token => reward balance
    mapping(address => mapping(address => uint256)) public override userBalances;

    modifier onlyPools() {
        require(msg.sender == pools, OnlyPools());
        _;
    }

    constructor(address _pools) Governable() {
        pools = _pools;
    }

    function setPools(address _pools) public onlyGov {
        pools = _pools;
    }

    function updatePoolConfig(bytes32 poolId, address token, uint256 poolRewardAmount) public override {
        require(msg.sender == pools || msg.sender == gov, InvalidCall());
        poolToken[poolId] = token;
        rewardAmount[poolId] = poolRewardAmount;
        emit UpdatedPoolConfig(poolId, token, poolRewardAmount);
    }

    // only pools
    function addInsurance(bytes32 poolId, uint256 amount) public override onlyPools {
        address token = poolToken[poolId];
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(assetBalances[token] + amount <= balance, InvalidAmount());
        poolBalances[poolId] += amount;
        assetBalances[poolToken[poolId]] = balance;
        
        emit InsuranceAdded(poolId, amount);
    }

    function donate(bytes32 poolId, uint256 amount) public {
        address token = poolToken[poolId];
        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        assetBalances[token] += amount;
        poolBalances[poolId] += amount;
        
        emit InsuranceDonated(poolId, amount);
    }

    function useInsurance(bytes32 poolId, uint256 amount) public override onlyPools {
        require(poolBalances[poolId] >= amount, InsufficientBalance());
        address token = poolToken[poolId];
        poolBalances[poolId] -= amount;
        assetBalances[token] -= amount;

        SafeERC20.safeTransfer(IERC20(token), pools, amount);
        emit InsuranceUsed(poolId, amount);
    }

    function liquidatorReward(bytes32 poolId, address liquidator) public override onlyPools {
        uint256 amount = rewardAmount[poolId];
        userBalances[liquidator][poolToken[poolId]] += amount;

        emit LiquidatorReward(poolId, liquidator, amount);
    }

    function brokeReward(bytes32 poolId, address trigger) public override onlyPools {
        uint256 amount = rewardAmount[poolId] * 10;
        userBalances[trigger][poolToken[poolId]] += amount;

        emit BrokeReward(poolId, trigger, amount);
    }

    function withdrawReward(address to, address token, uint256 amount) public {
        require(userBalances[msg.sender][token] >= amount, InsufficientBalance());
        userBalances[msg.sender][token] -= amount;

        SafeERC20.safeTransfer(IERC20(token), to, amount);
        assetBalances[token] = IERC20(token).balanceOf(address(this));

        emit WithdrawReward(token, to, amount);
    }

    function getInsurance(bytes32 poolId) public override view  returns (uint256) {
        return poolBalances[poolId];
    }

    // only manager
    function withdrawInsurance(bytes32 poolId, address to, uint256 amount) public override onlyGov {
        require(poolBalances[poolId] >= amount, InsufficientBalance());
        address token = poolToken[poolId];
        poolBalances[poolId] -= amount;
        assetBalances[token] -= amount;

        SafeERC20.safeTransfer(IERC20(token), to, amount);

        emit WithdrawInsurance(poolId, to, amount);
    }
}