// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IPlugin {
    error NotApprove();
    error Added();

    event AddedPlugin(address plugin);
    event RemovedPlugin(address plugin);

    event Approved(address indexed user, address indexed plugin, bool isApprove);


    function getPlugins() external view returns(address[] memory);
    function plugins(uint256 index) external view returns(address);
    function isPlugin(address plugin) external view returns(bool);
    function allowances(address user, address plugin) external view returns(bool);
    function approve(address plugin, bool isApprove) external;
}