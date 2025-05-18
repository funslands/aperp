// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

/// test plugin and Governable

import "forge-std/Test.sol";
import "../src/test/PluginRealize.sol";

contract PluginTest is Test {
    PluginRealize plugin;

    address public a1 = vm.addr(0xff323);
    address public a2 = vm.addr(0xff322);
    address public a3 = vm.addr(0xff321);

    function setUp() public {
        plugin = new PluginRealize();    
    }

    function checkGov() public {
        assertEq(plugin.gov(), address(this));
        plugin.setGov(a1);
        vm.expectRevert(Governable.notGov.selector);
        plugin.setGov(a2);
    }

    function testAddPlugin() public {
        plugin.addPlugin(address(this));
        assertTrue(plugin.isPlugin(address(this)));
        vm.expectRevert(IPlugin.Added.selector);
        plugin.addPlugin(address(this));

        vm.expectEmit();
        emit IPlugin.AddedPlugin(a1);
        plugin.addPlugin(a1);
        assertTrue(plugin.isPlugin(a1));
    }

    function testApprove() public {
        assertFalse(plugin.isPlugin(a1));
        plugin.addPlugin(a1);

        
        vm.expectRevert(IPlugin.NotApprove.selector);
        call(a2);

        vm.startPrank(a2);
        vm.expectEmit();
        emit IPlugin.Approved(a2, address(this), true);
        plugin.approve(address(this), true);
        vm.stopPrank();
        
        vm.assertTrue(plugin.allowances(a2, address(this)));
        call(a2);
        
    }

    function call(address user) private {
        plugin.checkApprove(user);
    }
}