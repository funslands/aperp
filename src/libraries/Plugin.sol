// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;
import "./Governable.sol";
import "../core/interfaces/IPlugin.sol";

abstract contract Plugin is IPlugin, Governable {
    address[] public override plugins;
    mapping(address => bool) public isPlugin;
    // user => plugins => is approve
    mapping(address => mapping(address=> bool)) public override allowances;

    modifier approved(address user) {
        require(allowances[user][msg.sender], NotApprove());
        _;
    }

    function getPlugins() public view returns(address[] memory) {
        return plugins;
    }

    function addPlugin(address plugin) public onlyGov() {
        require(!isPlugin[plugin], Added());
        plugins.push(plugin);
        isPlugin[plugin] = true;

        emit AddedPlugin(plugin);
    }

    function removePlugin(address plugin) public onlyGov() {
        if (isPlugin[plugin]) {
            uint256 len = plugins.length;
            for (uint256 i=0; i<len; i++) {
                if (plugins[i] == plugin) {
                    plugins[i] = plugins[len-1];
                    plugins.pop();
                    isPlugin[plugin] = false;

                    emit RemovedPlugin(plugin);

                    break;
                }
            }
        }
    }

    function approve(address plugin, bool isApprove) public override {
        allowances[msg.sender][plugin] = isApprove;

        emit Approved(msg.sender, plugin, isApprove);
    }
}