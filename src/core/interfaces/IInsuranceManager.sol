// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IInsuranceManager {

    error OnlyPools();
    error InvalidCall();
    error InvalidAmount();
    error InsufficientBalance();

    event UpdatedPoolConfig(bytes32 poolId, address token, uint256 poolRewardAmount);
    event InsuranceAdded(bytes32 poolId, uint256 amount);
    event InsuranceUsed(bytes32 poolId, uint256 amount);
    event LiquidaterReward(bytes32 poolId, address liquidater, uint256);
    event BrokeReward(bytes32 poolId, address liquidater, uint256);
    event InsuranceDonated(bytes32 poolId, uint256 amount);
    event WithdrawInsurance(bytes32 poolId, address to, uint256 amount);
    event WithdrawReward(address token, address to, uint256 amount);

    function userBalances(address, address) external view returns (uint256);

    function updatePoolConfig(bytes32 poolId, address token, uint256 poolRewardAmount) external;

    // only pools
    function addInsurance(bytes32 poolId, uint256 amount) external;
    function useInsurance(bytes32 poolId, uint256 amount) external;
    function liquidaterReward(bytes32 poolId, address liquidater) external;
    function brokeReward(bytes32 poolId, address liquidater) external;

    function getInsurance(bytes32 poolId) external view returns (uint256);
    // only manager
    function withdrawInsurance(bytes32 poolId, address to, uint256 amount) external;
}