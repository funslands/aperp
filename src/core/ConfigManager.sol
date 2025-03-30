// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./interfaces/IConfigManager.sol";
import "./interfaces/IPriceHelper.sol";
import "./interfaces/IMatchingEngine.sol";
import "../libraries/Governable.sol";
import "../libraries/Constant.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ConfigManager is IConfigManager, Governable {
    address public priceHelper;
    address public matchingEngine;
    address[] private assetList;
    bytes32[] private pairList;

    mapping (address=> AssetConfig) private assetConfigs;
    mapping (bytes32=> PairConfig) private pairConfigs;
    bytes[] private tickConfigs;

    constructor() {
        tickConfigs.push(abi.encode(0)); // placeholder 
    }

    function setConfig(address _priceHelper, address _matchingEngine) public onlyGov() {
        priceHelper = _priceHelper;
        matchingEngine = _matchingEngine;
    }

    function assetsList() public override view returns(address[] memory) {
        return assetList;
    }
    function pairsList() public override view returns(bytes32[] memory) {
        return pairList;
    }

    function getAssetConfig(address asset) public view override returns(AssetConfig memory) {
        return assetConfigs[asset];
    }

    function getPairConfig(bytes32 pairId) public view override returns(PairConfig memory) {
        return pairConfigs[pairId];
    }

    function addAsset(AssetConfig memory config, address oracle) public onlyGov() {
        require(config.multiplier >= 1e4 && config.multiplier <= 1e14, InvalidMultiplier()); 
        require(assetConfigs[config.token].token == address(0), AssetExisted()); 
        require(config.minimumMargin >= 1e4, InvalidMinimumMargin());
        require(config.makerLimit >= 1e20, InvalidMakerLimit());

        IPriceHelper(priceHelper).addPriceFeedId(bytes32(uint256(uint160(config.token))), config.pythFeedId, oracle, config.isStable);

        config.symbol = IERC20Metadata(config.token).symbol();
        config.decimals = IERC20Metadata(config.token).decimals();

        if (config.isStable) config.multiplier = Constant.BASIS_POINTS_DIVISOR; 

        assetList.push(config.token);
        assetConfigs[config.token] = config;

        emit AddedAsset(config.token, config.decimals, config.isStable, config.multiplier, config.pythFeedId, config.minimumMargin, config.makerLimit, config.symbol);
    }

    function updateAsset(address token, int64 multiplier, int256 minimumMargin, int256 makerLimit, bytes32 pythFeedId) public onlyGov() {
        require(multiplier >= 1e4 && multiplier <= 1e14, InvalidMultiplier());
        require(assetConfigs[token].token != address(0), AssetNotExist());
        require(minimumMargin >= 1e4, InvalidMinimumMargin());
        require(makerLimit >= 1e20, InvalidMakerLimit());

        if (assetConfigs[token].pythFeedId != pythFeedId) {
            IPriceHelper(priceHelper).updatePythFeedId(bytes32(uint256(uint160(token))), pythFeedId, assetConfigs[token].isStable);
            assetConfigs[token].pythFeedId = pythFeedId;
        }

        if (!assetConfigs[token].isStable) assetConfigs[token].multiplier = multiplier;
        assetConfigs[token].minimumMargin = minimumMargin;
        assetConfigs[token].makerLimit = makerLimit;

        emit UpdatedAsset(token, multiplier, pythFeedId, minimumMargin, makerLimit);
    }

    function updatePair(string memory pair, int256 im, int256 mm, bytes32 pythFeedId, int256 reserveRatio, int256 dust, address oracle) public onlyGov() {
        require(reserveRatio >= 1e7 && reserveRatio <= 5e7, InvalidReserveRatio());
        require(im >= 1e5 && im <= 1e7, InvalidIM()); // 10-1000X
        require(mm >= im/5 && mm <= im/2, InvalidMM()); 
        require(dust >= 1e15, InvalidDust());

        bytes32 pairId = keccak256(abi.encode(pair));
        if (pairConfigs[pairId].pairId == bytes32(0)) {
            pairList.push(pairId);
            IPriceHelper(priceHelper).addPriceFeedId(pairId, pythFeedId, oracle, false);
        }
        else if (pairConfigs[pairId].pythFeedId != pythFeedId) {
            IPriceHelper(priceHelper).updatePythFeedId(pairId, pythFeedId, false);
        }

        pairConfigs[pairId] = PairConfig({
            pair: pair,
            pairId: pairId,
            imRatio: im,
            mmRatio: mm,
            pythFeedId: pythFeedId,
            reserveRatio: reserveRatio,
            dust: dust
        });

        emit UpdatedPair(pairId, im, mm, pythFeedId, reserveRatio, dust, pair);
    }

    function getTickConfigNum() public override view returns(uint256) {
        return tickConfigs.length-1;
    }

    function getTickConfig(uint8 id) public view override returns(IMatchingEngine.TickConfig[] memory) {
        require(id > 0 && id <= tickConfigs.length, InvalidId());
        return abi.decode(tickConfigs[id], (IMatchingEngine.TickConfig[]));
    }

    function addTickConfig(IMatchingEngine.TickConfig[] memory config) public onlyGov {
        uint256 len = tickConfigs.length;
        require(len < 200, ConfigTooMuch());

        require(IMatchingEngine(matchingEngine).checkTickConfig(config), InvalidTickConfig());
        tickConfigs.push(abi.encode(config));

        emit AddedTickConfig(uint8(len), config);
    }

    function updateTickConfig(uint8 id, IMatchingEngine.TickConfig[] memory config) public onlyGov() {
        require(id > 0 && id <= tickConfigs.length-1, InvalidId());
        require(IMatchingEngine(matchingEngine).checkTickConfig(config), InvalidTickConfig());
        
        tickConfigs[id] = abi.encode(config);

        emit UpdatedTickConfig(id, config);
    }
}