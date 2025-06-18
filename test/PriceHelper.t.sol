// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Test.sol";
import "../src/core/PriceHelper.sol";
import "../src/test/TestToken.sol";
import "../src/test/TestOracle.sol";
import "../src/test/TestPythOracle.sol";

contract PriceHelperTest is Test {
    PriceHelper public ph;
    TestPythOracle public pyth;
    TestOracle public btcOracle;
    TestOracle public ethOracle;
    TestOracle public usdOracle;

    address public btc;
    address public eth;
    address public usd;

    address public a1 = vm.addr(0xff323);
    address public a2 = vm.addr(0xff322);
    address public cm = vm.addr(0xf0321);

    bytes32 btcFeedId;
    bytes32 usdFeedId;
    bytes32 ethFeedId;

    bytes32 btcPriceId;
    bytes32 usdPriceId;
    bytes32 ethPriceId;

    function setUp() public {
        pyth = new TestPythOracle();
        ph = new PriceHelper(cm, address(pyth));

        btc = address(new TestToken("warped BTC", "wBTC", 9));
        eth = address(new TestToken("warped ETH", "wETH", 18));
        eth = address(new TestToken("usd", "USD", 6));

        btcOracle = new TestOracle(8);
        ethOracle = new TestOracle(18);
        usdOracle = new TestOracle(8);


        
        btcFeedId = keccak256(abi.encode(btc));
        usdFeedId = keccak256(abi.encode(usd));
        ethFeedId = keccak256(abi.encode(eth));

        btcPriceId = bytes32(uint256(uint160(btc)));
        usdPriceId = bytes32(uint256(uint160(usd)));
        ethPriceId = bytes32(uint256(uint160(eth)));

        vm.deal(cm, 1 ether);
    }

    function setOracle() private {
        vm.deal(address(this), 1e18);
        bytes[] memory updateData = new bytes[](3);

        updateData[0] = abi.encode(btcFeedId, 80000e8);
        updateData[1] = abi.encode(ethFeedId, 2000e8);
        updateData[2] = abi.encode(usdFeedId, 1e8);
        pyth.updatePriceFeeds{value: 3}(updateData);

        btcOracle.updatePrice(80000e8);
        ethOracle.updatePrice(2000e18);
        usdOracle.updatePrice(1e8);

        vm.startPrank(cm);
        ph.addPriceFeedId(btcPriceId, btcFeedId, address(btcOracle), false);
        ph.addPriceFeedId(ethPriceId, ethFeedId, address(ethOracle), false);
        ph.addPriceFeedId(usdPriceId, usdFeedId, address(usdOracle), true);
        vm.stopPrank();        
    }

    function testUpdateConfig() public {
        vm.expectRevert(Governable.notGov.selector);
        vm.startPrank(a1);
        ph.updateConfig(a1, a2, 20, 2 hours, 1e7);
        vm.stopPrank();

        vm.expectEmit(address(ph));
        emit IPriceHelper.UpdatedConfig(a1, a2, 20, 2 hours, 1e6);
        ph.updateConfig(a1, a2, 20, 2 hours, 1e7);
        vm.assertEq(ph.configManager(), a1);
        vm.assertEq(ph.pythOracle(), a2);
        vm.assertEq(ph.pythEffectiveDuration(), 20);
        vm.assertEq(ph.oracleEffectiveDuration(), 2 hours);
        vm.assertEq(ph.maxDiffRatio(), 1e6);


        vm.expectEmit(address(ph));
        emit IPriceHelper.UpdatedConfig(a1, a2, 20, 2 hours, 5e6);
        ph.updateConfig(a1, a2, 3, 500, 5e6);
        vm.assertEq(ph.configManager(), a1);
        vm.assertEq(ph.pythOracle(), a2);
        vm.assertEq(ph.pythEffectiveDuration(), 20);
        vm.assertEq(ph.oracleEffectiveDuration(), 2 hours);
        vm.assertEq(ph.maxDiffRatio(), 5e6);
    }

    function testUpdatePythFeedId() public {
        vm.expectRevert(IPriceHelper.OnlyConfigManager.selector);
        bytes32 btc2 = keccak256(abi.encode(btc));
        ph.addPriceFeedId(btc2, btc2, address(btcOracle), false);

        vm.startPrank(cm);
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = abi.encode(btc2, 0);
        pyth.updatePriceFeeds{value: 1}(updateData);
        vm.expectRevert(abi.encodeWithSelector(IPriceHelper.ErrorPrice.selector, 0));
        ph.addPriceFeedId(btc2, btc2, address(btcOracle), false);

        
        updateData[0] = abi.encode(btc2, 80000e8);
        pyth.updatePriceFeeds{value: 1}(updateData);
        vm.expectRevert(abi.encodeWithSelector(IPriceHelper.ErrorPrice.selector, 0));
        ph.addPriceFeedId(btc2, btc2, address(btcOracle), false);

        btcOracle.updatePrice(81000e8);
        vm.expectRevert(IPriceHelper.InvalidPythFeedId.selector);
        ph.addPriceFeedId(btc2, btc2, address(btcOracle), false);

        btcOracle.updatePrice(80100e8);
        vm.expectEmit(address(ph));
        emit IPriceHelper.AddedPriceFeedId(btc2, btc2, address(btcOracle));
        ph.addPriceFeedId(btc2, btc2, address(btcOracle), false);
        vm.stopPrank();

        vm.assertEq(ph.pythFeedIds(btc2), btc2);

        bytes32 eth2 = keccak256(abi.encode(eth));
        vm.startPrank(a2);
        vm.expectRevert(IPriceHelper.InvalidCall.selector);
        ph.updatePythFeedId(eth2, eth2, false);
        vm.stopPrank();


        updateData[0] = abi.encode(eth2, 2000e8);
        pyth.updatePriceFeeds{value: 1}(updateData);
        ethOracle.updatePrice(2000e18);
        vm.startPrank(cm);
        ph.addPriceFeedId(eth2, eth2, address(ethOracle), false);
        vm.stopPrank();
        vm.expectEmit(address(ph));
        emit IPriceHelper.UpdatedOracle(eth2, address(ethOracle), 18);
        ph.updateOracle(eth2, address(ethOracle));
        vm.expectEmit(address(ph));
        emit IPriceHelper.UpdatedPythFeedId(eth2, eth2);
        ph.updatePythFeedId(eth2, eth2, false);
    } 

    function testGetIndexPrice() public {
        setOracle();
        vm.expectRevert(IPriceHelper.InvalidPriceId.selector);
        ph.getIndexPrice(usdFeedId);

        vm.warp(block.timestamp + 10);
        // test get usd price
        usdOracle.updatePrice(1);
        int256 price = ph.getIndexPrice(usdPriceId);
        vm.assertEq(price, 100);

        usdOracle.updatePrice(1e8);
        price = ph.getIndexPrice(usdPriceId);
        vm.assertEq(price, 1e10);

        usdOracle.updatePrice(101e6);
        price = ph.getIndexPrice(usdPriceId);
        vm.assertEq(price, 1e10);

        usdOracle.updatePrice(99e6);
        price = ph.getIndexPrice(usdPriceId);
        vm.assertEq(price, 1e10);

        usdOracle.updatePrice(133e6);
        price = ph.getIndexPrice(usdPriceId);
        vm.assertEq(price, 133e8);

        usdOracle.updatePrice(79e6);
        price = ph.getIndexPrice(usdPriceId);
        vm.assertEq(price, 79e8);

        // test get eth price
        vm.expectRevert(abi.encodeWithSelector(IPriceHelper.PriceInactivation.selector, 2000e10, 1));
        ph.getIndexPrice(ethPriceId);
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = abi.encode(ethFeedId, 2000e8);
        pyth.updatePriceFeeds{value: 1}(updateData);
        ethOracle.updatePrice(2300e18);
        vm.expectRevert(abi.encodeWithSelector(IPriceHelper.PythPriceError.selector, 2000e10, 2300e10));
        ph.getIndexPrice(ethPriceId);

        ethOracle.updatePrice(2005e18);
        price = ph.getIndexPrice(ethPriceId);
        vm.assertEq(price, 2000e10);

        ethOracle.updatePrice(1990e18);
        price = ph.getIndexPrice(ethPriceId);
        vm.assertEq(price, 2000e10);

        ethOracle.updatePrice(2000e18);
        price = ph.getIndexPrice(ethPriceId);
        vm.assertEq(price, 2000e10);

        updateData[0] = abi.encode(ethFeedId, 2019e8);
        pyth.updatePriceFeeds{value: 1}(updateData);
        price = ph.getIndexPrice(ethPriceId);
        vm.assertEq(price, 2019e10);

        updateData[0] = abi.encode(ethFeedId, 1990e8);
        pyth.updatePriceFeeds{value: 1}(updateData);
        price = ph.getIndexPrice(ethPriceId);
        vm.assertEq(price, 1990e10);
    }

    function testSetPrice() public {
        setOracle();
        vm.warp(vm.unixTime());
        btcOracle.updatePrice(80000e8);
        usdOracle.updatePrice(1e8);
        ethOracle.updatePrice(2000e18);
        bytes32[] memory priceId3 = new bytes32[](3);
        bytes[] memory priceUpdateData3 = new bytes[](3);
        priceUpdateData3[0] = abi.encode(btcFeedId, 80001e8);
        priceUpdateData3[1] = abi.encode(ethFeedId, 2001e8);
        priceUpdateData3[2] = abi.encode(usdFeedId, 99e6);
        priceId3[0] = btcFeedId;
        priceId3[1] = ethFeedId;
        priceId3[2] = usdFeedId;
        ph.updatePrice{value: 3}(priceId3, priceUpdateData3);
        int256 price = ph.getIndexPrice(btcPriceId);
        vm.assertEq(price, 80001e10);
        price = ph.getIndexPrice(ethPriceId);
        vm.assertEq(price, 2001e10);
        price = ph.getIndexPrice(usdPriceId);
        vm.assertEq(price, 1e10);


        bytes32[] memory priceId2 = new bytes32[](2);
        bytes[] memory priceUpdateData2 = new bytes[](2);
        priceUpdateData2[0] = abi.encode(btcFeedId, 80005e8);
        priceUpdateData2[1] = abi.encode(ethFeedId, 2005e8);
        priceId2[0] = btcFeedId;
        priceId2[1] = ethFeedId;
        ph.updatePrice{value: 2}(priceId2, priceUpdateData2);
        price = ph.getIndexPrice(btcPriceId);
        vm.assertEq(price, 80005e10);
        price = ph.getIndexPrice(ethPriceId);
        vm.assertEq(price, 2005e10);
        price = ph.getIndexPrice(usdPriceId);
        vm.assertEq(price, 1e10);

        bytes32[] memory priceId1 = new bytes32[](1);
        bytes[] memory priceUpdateData1 = new bytes[](1);
        priceUpdateData1[0] = abi.encode(btcFeedId, 80015e8);
        priceId1[0] = btcFeedId;
        ph.updatePrice{value: 1}(priceId1, priceUpdateData1);
        price = ph.getIndexPrice(btcPriceId);
        vm.assertEq(price, 80015e10);
        price = ph.getIndexPrice(ethPriceId);
        vm.assertEq(price, 2005e10);
        price = ph.getIndexPrice(usdPriceId);
        vm.assertEq(price, 1e10);
    }
}