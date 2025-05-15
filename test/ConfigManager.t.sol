// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Test.sol";
import "../src/core/ConfigManager.sol";
import "../src/core/PriceHelper.sol";
import "../src/core/MatchingEngine.sol";
import "../src/test/TestToken.sol";
import "../src/test/TestOracle.sol";
import "../src/test/TestPythOracle.sol";


contract ConfigManagerTest is Test {
    ConfigManager public cm;
    PriceHelper public ph;
    TestPythOracle public pyth;
    MatchingEngine public me;

    TestOracle public btcOracle;
    TestOracle public ethOracle;
    TestOracle public usdOracle;

    address a1 = vm.addr(0xff323);
    address a2 = vm.addr(0xff322);
    address pools = vm.addr(0xf0321);

    address public btc;
    address public eth;
    address public usd;

    
    bytes32 btcFeedId;
    bytes32 usdFeedId;
    bytes32 ethFeedId;

    bytes32 btcPriceId;
    bytes32 usdPriceId;
    bytes32 ethPriceId;

    function setUp() public {
        pyth = new TestPythOracle();
        me = new MatchingEngine(pools);
        cm = new ConfigManager();

        ph = new PriceHelper(address(cm), address(pyth));

        cm.setConfig(address(ph), address(me));

        btc = address(new TestToken("warped BTC", "wBTC", 9));
        eth = address(new TestToken("warped ETH", "wETH", 18));
        usd = address(new TestToken("usd", "USD", 6));

        btcOracle = new TestOracle(8);
        ethOracle = new TestOracle(8);
        usdOracle = new TestOracle(8);

        
        btcFeedId = keccak256(abi.encode(btc));
        usdFeedId = keccak256(abi.encode(usd));
        ethFeedId = keccak256(abi.encode(eth));

        btcPriceId = bytes32(uint256(uint160(btc)));
        usdPriceId = bytes32(uint256(uint160(usd)));
        ethPriceId = bytes32(uint256(uint160(eth)));

        vm.deal(address(this), 1 ether);
        vm.warp(vm.unixTime());
    }

    function testSetConfig() public {
        vm.startPrank(a2);
        vm.expectRevert(Governable.notGov.selector);
        cm.setConfig(btc, usd);
        vm.stopPrank();

        cm.setConfig(btc, usd);
        vm.assertEq(cm.priceHelper(), btc);
        vm.assertEq(cm.matchingEngine(), usd);
    }

    function testAsset() public {
        IConfigManager.AssetConfig memory ethConfig = IConfigManager.AssetConfig({
            token: eth,
            decimals: 20,
            isStable: false, 
            pythFeedId: ethFeedId,
            multiplier: 1000e8,
            minimumMargin: 1e17, // 0.1 eth
            makerLimit: 10000e20,
            symbol: "eth"
        });
        IConfigManager.AssetConfig memory btcConfig = IConfigManager.AssetConfig({
            token: btc,
            decimals: 20,
            isStable: false, 
            pythFeedId: btcFeedId,
            multiplier: 10000e8,
            minimumMargin: 1e6, // 0.001 btc
            makerLimit: 1000e20,
            symbol: "btc"
        });
        IConfigManager.AssetConfig memory usdConfig = IConfigManager.AssetConfig({
            token: usd,
            decimals: 20,
            isStable: true, 
            pythFeedId: usdFeedId,
            multiplier: 1e10,
            minimumMargin: 50e6, // 50 usd
            makerLimit: 100000000e20,
            symbol: "usd"
        });

        // notGov
        vm.startPrank(a2);
        vm.expectRevert(Governable.notGov.selector);
        cm.addAsset(ethConfig, address(ethOracle));
        vm.expectRevert(Governable.notGov.selector);
        cm.updateAsset(eth, 1000e8, 1e17, 1e23, ethFeedId);
        vm.stopPrank();

        // InvalidPythFeedId
        vm.expectRevert(abi.encodeWithSelector(IPriceHelper.ErrorPrice.selector, 0));
        cm.addAsset(usdConfig, address(usdOracle));

        updatePrice();

        // other error
        IConfigManager.AssetConfig memory testConfig = IConfigManager.AssetConfig({
            token: eth,
            decimals: 20,
            isStable: false, 
            pythFeedId: ethFeedId,
            multiplier: 1000e8,
            minimumMargin: 1e17, // 0.1 eth
            makerLimit: 1000e20,
            symbol: "eth"
        });
        testConfig.multiplier = 1e4-1;
        vm.expectRevert(IConfigManager.InvalidMultiplier.selector);
        cm.addAsset(testConfig, address(ethOracle));
        testConfig.multiplier = 1e14+1;
        vm.expectRevert(IConfigManager.InvalidMultiplier.selector);
        cm.addAsset(testConfig, address(ethOracle));

        testConfig.multiplier = 1e5;
        testConfig.minimumMargin = 1e4-1;  
        vm.expectRevert(IConfigManager.InvalidMinimumMargin.selector);
        cm.addAsset(testConfig, address(ethOracle));

        testConfig.minimumMargin = 1e18;  
        testConfig.makerLimit = 1e20-1;
        vm.expectRevert(IConfigManager.InvalidMakerLimit.selector);
        cm.addAsset(testConfig, address(ethOracle));

        IConfigManager.AssetConfig memory config;
        address[] memory assetList;
        // add asset
        vm.expectEmit(address(cm));
        emit IConfigManager.AddedAsset(btcConfig.token, 9, false, btcConfig.multiplier, btcConfig.pythFeedId, btcConfig.minimumMargin, btcConfig.makerLimit, "wBTC");
        cm.addAsset(btcConfig, address(btcOracle));
        config = cm.getAssetConfig(btc);
        vm.assertEq(config.decimals, 9);
        vm.assertEq(config.symbol, "wBTC");
        vm.assertEq(config.minimumMargin, btcConfig.minimumMargin);
        vm.assertEq(config.pythFeedId, btcConfig.pythFeedId);
        vm.assertEq(config.makerLimit, btcConfig.makerLimit);
        assetList = cm.assetsList();
        vm.assertEq(assetList.length, 1);

        vm.expectEmit(address(cm));
        emit IConfigManager.AddedAsset(ethConfig.token, 18, false, ethConfig.multiplier, ethConfig.pythFeedId, ethConfig.minimumMargin, ethConfig.makerLimit, "wETH");
        cm.addAsset(ethConfig, address(ethOracle));
        config = cm.getAssetConfig(eth);
        vm.assertEq(config.decimals, 18);
        vm.assertEq(config.symbol, "wETH");
        vm.assertEq(config.minimumMargin, ethConfig.minimumMargin);
        vm.assertEq(config.pythFeedId, ethConfig.pythFeedId);
        vm.assertEq(config.makerLimit, ethConfig.makerLimit);
        assetList = cm.assetsList();
        vm.assertEq(assetList.length, 2);

        vm.expectEmit(address(cm));
        emit IConfigManager.AddedAsset(usdConfig.token, 6, true, 1e8, usdConfig.pythFeedId, usdConfig.minimumMargin, usdConfig.makerLimit, "USD");
        cm.addAsset(usdConfig, address(usdOracle));
        config = cm.getAssetConfig(usd);
        vm.assertEq(config.decimals, 6);
        vm.assertEq(config.symbol, "USD");
        vm.assertEq(config.minimumMargin, usdConfig.minimumMargin);
        vm.assertEq(config.pythFeedId, usdConfig.pythFeedId);
        vm.assertEq(config.makerLimit, usdConfig.makerLimit);
        vm.assertEq(config.multiplier, 1e8);
        assetList = cm.assetsList();
        vm.assertEq(assetList.length, 3);

        // AssetExisted
        vm.expectRevert(IConfigManager.AssetExisted.selector);
        cm.addAsset(btcConfig, address(btcOracle));
        vm.expectRevert(IConfigManager.AssetExisted.selector);
        cm.addAsset(ethConfig, address(ethOracle));
        vm.expectRevert(IConfigManager.AssetExisted.selector);
        cm.addAsset(usdConfig, address(usdOracle));

        vm.expectRevert(IConfigManager.AssetNotExist.selector);
        cm.updateAsset(a1, 100000e8, 2e6, 1000e20, ethFeedId);

        vm.expectRevert(IConfigManager.InvalidMinimumMargin.selector);
        cm.updateAsset(btc, 100000e8, 0, 1000e20, ethFeedId);
        vm.expectRevert(IConfigManager.InvalidMakerLimit.selector);
        cm.updateAsset(btc, 100000e8, 2e6, 1e9, ethFeedId);

        // update asset
        vm.expectEmit(address(cm));
        emit IConfigManager.UpdatedAsset(btc, 100000e8, btcFeedId, 2e6, 1e22);
        cm.updateAsset(btc, 100000e8, 2e6, 1e22, btcFeedId);
        config = cm.getAssetConfig(btc);
        vm.assertEq(config.multiplier, 100000e8);
        vm.assertEq(config.minimumMargin, 2e6);
        vm.assertEq(config.pythFeedId, btcFeedId);
        vm.assertEq(config.makerLimit, 1e22);
        assetList = cm.assetsList();
        vm.assertEq(assetList.length, 3);
        

        cm.updateAsset(eth, 100000e8, 2e6, 1e22, ethFeedId);
        config = cm.getAssetConfig(eth);
        vm.assertEq(config.multiplier, 100000e8);
        vm.assertEq(config.minimumMargin, 2e6);
        vm.assertEq(config.pythFeedId, ethFeedId);
        vm.assertEq(config.makerLimit, 1e22);

        cm.updateAsset(usd, 100000e8, 2e6, 1e22, usdFeedId);
        config = cm.getAssetConfig(usd);
        vm.assertEq(config.multiplier, 1e8);
        vm.assertEq(config.minimumMargin, 2e6);
        vm.assertEq(config.pythFeedId, usdFeedId);
        vm.assertEq(config.makerLimit, 1e22);

        assetList = cm.assetsList();
        vm.assertEq(assetList.length, 3);
    }

    function testPair() public {
        // notGov
        vm.startPrank(a2);
        vm.expectRevert(Governable.notGov.selector);
        cm.updatePair("BTC/USD", 1e6, 5e5, btcFeedId, 2e7, 1e15, address(btcOracle));
        vm.expectRevert(Governable.notGov.selector);
        cm.updatePair("ETH/USD", 1e6, 5e5, ethFeedId, 2e7, 1e16, address(ethOracle));
        vm.stopPrank();

        
        vm.expectRevert(abi.encodeWithSelector(IPriceHelper.ErrorPrice.selector, 0));
        cm.updatePair("BTC/USD", 1e6, 5e5, btcFeedId, 2e7, 1e15, address(ethOracle));
        vm.expectRevert(abi.encodeWithSelector(IPriceHelper.ErrorPrice.selector, 0));
        cm.updatePair("ETH/USD", 1e6, 5e5, ethFeedId, 2e7, 1e16, address(ethOracle));

        vm.expectRevert(IConfigManager.InvalidIM.selector);
        cm.updatePair("BTC/USD", 1e5-1, 5e5, btcFeedId, 2e7, 1e15, address(btcOracle));
        vm.expectRevert(IConfigManager.InvalidIM.selector);
        cm.updatePair("BTC/USD", 1e7+1, 5e5, btcFeedId, 2e7, 1e15, address(btcOracle));

        vm.expectRevert(IConfigManager.InvalidMM.selector);
        cm.updatePair("BTC/USD", 1e6, 1e6/5-1, btcFeedId, 2e7, 1e15, address(btcOracle));
        vm.expectRevert(IConfigManager.InvalidMM.selector);
        cm.updatePair("BTC/USD", 1e6, 1e6/2+1, btcFeedId, 2e7, 1e15, address(btcOracle));
        
        vm.expectRevert(IConfigManager.InvalidReserveRatio.selector);
        cm.updatePair("BTC/USD", 1e6, 5e5, btcFeedId, 1e7-1, 1e15, address(btcOracle));
        vm.expectRevert(IConfigManager.InvalidReserveRatio.selector);
        cm.updatePair("BTC/USD", 1e6, 5e5, btcFeedId, 5e7+1, 1e15, address(btcOracle));

        vm.expectRevert(IConfigManager.InvalidDust.selector);
        cm.updatePair("BTC/USD", 1e6, 5e5, btcFeedId, 2e7, 1e15-1, address(btcOracle));

        updatePrice();
        bytes32 btcPairId = keccak256(abi.encode("BTC/USD"));
        IConfigManager.PairConfig memory config;
        bytes32[] memory pairList;
        vm.expectEmit(address(cm));
        emit IConfigManager.UpdatedPair(btcPairId, 1e6, 5e5, btcFeedId, 2e7, 1e15, "BTC/USD");
        cm.updatePair("BTC/USD", 1e6, 5e5, btcFeedId, 2e7, 1e15, address(btcOracle));
        pairList = cm.pairsList();
        vm.assertEq(pairList.length, 1);
        config = cm.getPairConfig(btcPairId);
        vm.assertEq(config.pairId, btcPairId);
        vm.assertEq(config.imRatio, 1e6);
        vm.assertEq(config.mmRatio, 5e5);
        vm.assertEq(config.pythFeedId, btcFeedId);
        vm.assertEq(config.reserveRatio, 2e7);
        vm.assertEq(config.dust, 1e15);
        vm.assertEq(config.pair, "BTC/USD");

        cm.updatePair("BTC/USD", 5e6, 2e6, btcFeedId, 3e7, 1e15, address(btcOracle));
        pairList = cm.pairsList();
        vm.assertEq(pairList.length, 1);
        config = cm.getPairConfig(btcPairId);
        vm.assertEq(config.pairId, btcPairId);
        vm.assertEq(config.imRatio, 5e6);
        vm.assertEq(config.mmRatio, 2e6);
        vm.assertEq(config.pythFeedId, btcFeedId);
        vm.assertEq(config.reserveRatio, 3e7);
        vm.assertEq(config.dust, 1e15);
        vm.assertEq(config.pair, "BTC/USD");


        bytes32 ethPairId = keccak256(abi.encode("ETH/USD"));
        vm.expectEmit(address(cm));
        emit IConfigManager.UpdatedPair(ethPairId, 1e6, 5e5, ethFeedId, 2e7, 1e16, "ETH/USD");
        cm.updatePair("ETH/USD", 1e6, 5e5, ethFeedId, 2e7, 1e16, address(ethOracle));
        pairList = cm.pairsList();
        vm.assertEq(pairList.length, 2);
        config = cm.getPairConfig(ethPairId);
        vm.assertEq(config.pairId, ethPairId);
        vm.assertEq(config.imRatio, 1e6);
        vm.assertEq(config.mmRatio, 5e5);
        vm.assertEq(config.pythFeedId, ethFeedId);
        vm.assertEq(config.reserveRatio, 2e7);
        vm.assertEq(config.dust, 1e16);
        vm.assertEq(config.pair, "ETH/USD");

        cm.updatePair("ETH/USD", 5e6, 2e6, ethFeedId, 3e7, 1e16, address(ethOracle));
        pairList = cm.pairsList();
        vm.assertEq(pairList.length, 2);
        config = cm.getPairConfig(ethPairId);
        vm.assertEq(config.pairId, ethPairId);
        vm.assertEq(config.imRatio, 5e6);
        vm.assertEq(config.mmRatio, 2e6);
        vm.assertEq(config.pythFeedId, ethFeedId);
        vm.assertEq(config.reserveRatio, 3e7);
        vm.assertEq(config.dust, 1e16);
        vm.assertEq(config.pair, "ETH/USD");
    }

    function updatePrice() private {
        // update price
        bytes32[] memory priceIds = new bytes32[](3);
        bytes[] memory priceUpdateData = new bytes[](3);
        priceIds[0] = btcFeedId;
        priceIds[1] = ethFeedId;
        priceIds[2] = usdFeedId;
        priceUpdateData[0] = abi.encode(btcFeedId, 80001e8);
        priceUpdateData[1] = abi.encode(ethFeedId, 2001e8);
        priceUpdateData[2] = abi.encode(usdFeedId, 101e6);
        ph.updatePrice{value: 3}(priceIds, priceUpdateData);

        btcOracle.updatePrice(80000e8);
        ethOracle.updatePrice(2000e8);
        usdOracle.updatePrice(1e8);
    }


    function testTickConfig() public {
        MatchingEngine.TickConfig[] memory config1 = new MatchingEngine.TickConfig[](2);

        MatchingEngine.TickConfig memory c1;
        MatchingEngine.TickConfig memory c2;

        c1.slippage = Constant.BASIS_POINTS_DIVISOR;
        c1.usageRatio = Constant.BASIS_POINTS_DIVISOR;

        vm.startPrank(a1);
        vm.expectRevert(Governable.notGov.selector);
        cm.addTickConfig(config1);
        vm.stopPrank();

        vm.expectRevert(IConfigManager.InvalidTickConfig.selector);
        cm.addTickConfig(config1);
        
        vm.expectRevert(IConfigManager.InvalidId.selector);
        cm.updateTickConfig(0, config1);

        vm.expectRevert(IConfigManager.InvalidId.selector);
        cm.updateTickConfig(1, config1);

        MatchingEngine.TickConfig[] memory config2 = new MatchingEngine.TickConfig[](3);
        c1.usageRatio = 1e7;
        c1.slippage = 1e6;
        c2.usageRatio = Constant.BASIS_POINTS_DIVISOR;
        c2.slippage = 1e7;
        config2[1] = c1;
        config2[2] = c2;
        cm.addTickConfig(config2);
        vm.assertEq(cm.getTickConfigNum(), 1);
        vm.assertEq(abi.encode(cm.getTickConfig(1)), abi.encode(config2));

        c2.slippage = 2e7;
        cm.updateTickConfig(1, config2);
        vm.assertEq(cm.getTickConfigNum(), 1);
        vm.assertEq(abi.encode(cm.getTickConfig(1)), abi.encode(config2));


        MatchingEngine.TickConfig memory c3;
        c1.usageRatio = 1e7;
        c1.slippage = 1e6;
        c2.usageRatio = 3e7;
        c2.slippage = 3e6;
        c3.usageRatio = Constant.BASIS_POINTS_DIVISOR;
        c3.slippage = 1e7;

        MatchingEngine.TickConfig[] memory config3 = new MatchingEngine.TickConfig[](4);
        config3[1] = c1;
        config3[2] = c2;
        config3[3] = c3;
        cm.addTickConfig(config3);
        vm.assertEq(cm.getTickConfigNum(), 2);
        vm.assertEq(abi.encode(cm.getTickConfig(2)), abi.encode(config3));

        cm.updateTickConfig(2, config3);
        vm.assertEq(cm.getTickConfigNum(), 2);
        vm.assertEq(abi.encode(cm.getTickConfig(2)), abi.encode(config3));
    }
}