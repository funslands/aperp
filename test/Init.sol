// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Test.sol";
import "../src/core/Markets.sol";
import "../src/core/Pools.sol";
import "../src/core/PriceHelper.sol";
import "../src/core/MatchingEngine.sol";
import "../src/core/ConfigManager.sol";
import "../src/core/InsuranceManager.sol";
import "../src/staking/Staker.sol";
import "../src/test/TestToken.sol";
import "../src/test/WETH9.sol";
import "../src/test/TestOracle.sol";
import "../src/test/TestPythOracle.sol";

abstract contract Init is Test {
    Pools public pools;
    MatchingEngine public me;
    ConfigManager public cm;
    InsuranceManager public im;
    PriceHelper public ph;
    TestPythOracle public pyth;
    Markets public markets;
    Staker public staker;

    TestToken public btc;
    WETH9 public eth;
    TestToken public usd;

    TestOracle public btcOracle;
    TestOracle public ethOracle;
    TestOracle public usdOracle;

    address public a1 = vm.addr(0xff321);
    address public a2 = vm.addr(0xff322);

    bytes32 public btcId;
    bytes32 public ethId;
    bytes32 public usdId;

    bytes32 public btcPoolId;
    bytes32 public usdPoolId;
    bytes32 public ethPoolId;

    bytes32 public btcPairId;
    bytes32 public ethPairId;

    uint256 public initTime;


    struct PriceInfo {
        bytes32 pythId;
        address oracle;
        address token;
    }

    // priceId => info
    mapping(bytes32=> PriceInfo) public priceInfos;

    function initial() public {
        vm.label(a1, "A1");
        vm.label(a2, "A2");
        
        initTime = 1740765700;
        vm.warp(initTime);
        vm.deal(address(this), 51 ether);
        pyth = new TestPythOracle();
        pools = new Pools();
        me = new MatchingEngine(address(pools));
        cm = new ConfigManager();
        ph = new PriceHelper(address(cm), address(pyth));
        im = new InsuranceManager(address(pools));
        markets = new Markets(address(pools), address(cm));
        
        btc = new TestToken("warpped BTC", "wBTC", 9);
        eth = new WETH9();
        usd = new TestToken("usd", "USD", 6);
        vm.label(address(btc), "wBTC");
        vm.label(address(usd), "USD");

        staker = new Staker(address(eth));
        pools.setConfig(address(markets), address(cm), address(ph), address(me), address(im), address(staker), address(eth), 900);
        cm.setConfig(address(ph), address(me));

        btcOracle = new TestOracle(8);
        ethOracle = new TestOracle(8);
        usdOracle = new TestOracle(8);

        btcId = getPriceId(btc);
        ethId = getPriceId(TestToken(address(eth)));
        usdId = getPriceId(usd);

        priceInfos[btcId] = PriceInfo({
            pythId: getFeedId(btc),
            oracle: address(btcOracle),
            token:  address(btc)
        });
        priceInfos[ethId] = PriceInfo({
            pythId: getFeedId(TestToken(address(eth))),
            oracle: address(ethOracle),
            token:  address(eth)
        });
        priceInfos[usdId] = PriceInfo({
            pythId: getFeedId(usd),
            oracle: address(usdOracle),
            token:  address(usd)
        });

        setPrice(btcId, 80000e8);
        setPrice(ethId, 2000e8);
        setPrice(usdId, 1e8);

        cm.addAsset(IConfigManager.AssetConfig({
            token: address(btc),
            decimals: 0, 
            isStable: false,
            pythFeedId: priceInfos[btcId].pythId,
            multiplier: 10000e8,
            minimumMargin: 1e6,
            makerLimit: 100e20,
            symbol: ""
        }), address(btcOracle));

        cm.addAsset(IConfigManager.AssetConfig({
            token: address(eth),
            decimals: 0, 
            isStable: false,
            pythFeedId: priceInfos[ethId].pythId,
            multiplier: 1000e8,
            minimumMargin: 1e16,
            makerLimit: 10000e20,
            symbol: ""
        }), address(ethOracle));

        cm.addAsset(IConfigManager.AssetConfig({
            token: address(usd),
            decimals: 0, 
            isStable: false,
            pythFeedId: priceInfos[usdId].pythId,
            multiplier: 1e8,
            minimumMargin: 50e6,
            makerLimit: 100000000e20,
            symbol: ""

        }), address(usdOracle));

        cm.updatePair("BTC/USD", 1e6, 5e5, priceInfos[btcId].pythId, 2e7, 1e15, priceInfos[btcId].oracle);
        cm.updatePair("ETH/USD", 1e6, 5e5, priceInfos[ethId].pythId, 2e7, 1e16, priceInfos[ethId].oracle);

        IMatchingEngine.TickConfig[] memory tickConfig = new IMatchingEngine.TickConfig[](7);
        tickConfig[0] = IMatchingEngine.TickConfig({usageRatio: 0, slippage: 0});
        tickConfig[1] = IMatchingEngine.TickConfig({usageRatio: 1e6, slippage: 5e4});
        tickConfig[2] = IMatchingEngine.TickConfig({usageRatio: 5e6, slippage: 30e4});
        tickConfig[3] = IMatchingEngine.TickConfig({usageRatio: 1e7, slippage: 65e4});
        tickConfig[4] = IMatchingEngine.TickConfig({usageRatio: 2e7, slippage: 145e4});
        tickConfig[5] = IMatchingEngine.TickConfig({usageRatio: 5e7, slippage: 420e4});
        tickConfig[6] = IMatchingEngine.TickConfig({usageRatio: 1e8, slippage: 1e7});
        cm.addTickConfig(tickConfig);

        tickConfig[1] = IMatchingEngine.TickConfig({usageRatio: 1e6, slippage: 8e4});
        tickConfig[2] = IMatchingEngine.TickConfig({usageRatio: 5e6, slippage: 44e4});
        tickConfig[3] = IMatchingEngine.TickConfig({usageRatio: 1e7, slippage: 94e4});
        tickConfig[4] = IMatchingEngine.TickConfig({usageRatio: 2e7, slippage: 210e4});
        tickConfig[5] = IMatchingEngine.TickConfig({usageRatio: 5e7, slippage: 600e4});
        tickConfig[6] = IMatchingEngine.TickConfig({usageRatio: 1e8, slippage: 15e6});
        cm.addTickConfig(tickConfig);

        tickConfig[1] = IMatchingEngine.TickConfig({usageRatio: 1e6, slippage: 10e4});
        tickConfig[2] = IMatchingEngine.TickConfig({usageRatio: 5e6, slippage: 60e4});
        tickConfig[3] = IMatchingEngine.TickConfig({usageRatio: 1e7, slippage: 150e4});
        tickConfig[4] = IMatchingEngine.TickConfig({usageRatio: 2e7, slippage: 300e4});
        tickConfig[5] = IMatchingEngine.TickConfig({usageRatio: 5e7, slippage: 800e4});
        tickConfig[6] = IMatchingEngine.TickConfig({usageRatio: 1e8, slippage: 2e7});
        cm.addTickConfig(tickConfig);

        btc.mint(address(this), 1e18);
        btc.approve(address(pools), 1e18);
        usd.mint(address(this), 1e18);
        usd.approve(address(pools), 1e18);
        eth.deposit{value: 50e18}();
        eth.approve(address(pools), 50e18);
        usdPoolId = pools.createPool(getPairId("BTC/USD"), address(usd), 110000e6, 1);
        btcPoolId = pools.createPool(getPairId("ETH/USD"), address(btc), 2e9, 1);
        ethPoolId = pools.createPool(getPairId("ETH/USD"), address(eth), 50e18, 1);
    }

    function setPrice(bytes32 priceId, int256 price) public {
        bytes32[] memory priceIds = new bytes32[](1);
        priceIds[0] = priceInfos[priceId].pythId;
        bytes[] memory priceUpdateData = new bytes[](1);
        priceUpdateData[0] = abi.encode(priceInfos[priceId].pythId, price);
        ph.updatePrice{value: 1}(priceIds, priceUpdateData);

        TestOracle(priceInfos[priceId].oracle).updatePrice(price);
    }
    
    function getPriceId(TestToken token) public pure returns(bytes32) {
        return bytes32(uint256(uint160(address(token))));
    }

    function getFeedId(TestToken token) public pure returns(bytes32) {
        return keccak256(abi.encode(address(token)));
    }

    function getPairId(string memory pair) public pure returns(bytes32) {
        return keccak256(abi.encode(pair));
    }
}