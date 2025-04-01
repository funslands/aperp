// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "../libraries/Governable.sol";
import "../libraries/Constant.sol";
import "./interfaces/IPriceHelper.sol";
import "./interfaces/AggregatorV2V3Interface.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";


contract PriceHelper is IPriceHelper, Governable {
    address public configManager;
    address public pythOracle;
    uint32 public pythEffectiveDuration = 10;
    uint32 public oracleEffectiveDuration = 1 hours;
    int32 public maxDiffRatio = 1e6; // 1%
    mapping(bytes32=> bool) public isStablePrice;
    // priceId => pythFeedId
    mapping(bytes32=> bytes32) public pythFeedIds;
    // priceId => oracle address
    mapping(bytes32=> address) public oracles; // address for chainlink oracle price
    mapping(bytes32=> uint8) public oracleDecimals; // decimals for chainlink oracle price
    

    constructor(address _configManager, address _pythOracle) {
        configManager = _configManager;
        pythOracle = _pythOracle;
    }

    function updateConfig(
        address _configManager,
        address _pythOracle,
        uint32 _pythEffectiveDuration,
        uint32 _oracleEffectiveDuration,
        int32 _maxDiffRatio
    ) public onlyGov() {
        if (_configManager != address(0)) configManager = _configManager;
        if (_pythOracle != address(0)) pythOracle = _pythOracle;
        if (_pythEffectiveDuration > 5 && _pythEffectiveDuration < 30) pythEffectiveDuration = _pythEffectiveDuration;
        if (_oracleEffectiveDuration > 1 hours && _oracleEffectiveDuration < 8 hours) oracleEffectiveDuration = _oracleEffectiveDuration;
        if (_maxDiffRatio >= 1e5 && _maxDiffRatio <= 5e6) maxDiffRatio = _maxDiffRatio; // 0.1%-5%

        emit UpdatedConfig(configManager, pythOracle, pythEffectiveDuration, oracleEffectiveDuration, maxDiffRatio);
    }

    function addPriceFeedId(bytes32 priceId, bytes32 pythFeedId, address oracle,  bool isStable) public override {
        require(msg.sender == configManager, OnlyConfigManager());
        if (pythFeedIds[priceId] != bytes32(0)) return;
        pythFeedIds[priceId] = pythFeedId;
        if (isStable) isStablePrice[priceId] = true;

        oracles[priceId] = oracle;

        uint8 decimals = AggregatorV2V3Interface(oracle).decimals();
        oracleDecimals[priceId] = decimals;

        require(checkDiff(getPythPrice(priceId), getOraclePrice(priceId)), InvalidPythFeedId());

        emit AddedPriceFeedId(priceId, pythFeedId, oracle);
    }

    function updatePythFeedId(bytes32 priceId, bytes32 pythFeedId, bool isStable) public override {
        require(msg.sender == gov || msg.sender == configManager, InvalidCall());
        pythFeedIds[priceId] = pythFeedId;
        isStablePrice[priceId] = isStable;

        require(checkDiff(getPythPrice(priceId), getOraclePrice(priceId)), InvalidPythFeedId());
        emit UpdatedPythFeedId(priceId, pythFeedId);
    }

    function updateOracle(bytes32 priceId, address oracle) public onlyGov() {
        oracles[priceId] = oracle;

        uint8 decimals = AggregatorV2V3Interface(oracle).decimals();
        oracleDecimals[priceId] = decimals;
        
        require(checkDiff(getPythPrice(priceId), getOraclePrice(priceId)), InvalidPythFeedId());
        emit UpdatedOracle(priceId, oracle, decimals);
    }

    function adjustPricePrecision(int256 price, uint32 currentDecimals, int256 precision) pure public returns(int256) {
        require(currentDecimals < 22, InvalidDecimals());
        if (price <= 0) return 0;
        return price * precision / int256(10** currentDecimals);
    }

    function getStablePrice(int256 price) pure private returns(int256) {
        int256 diff = price - Constant.PRICE_PRECISION;
        if (diff < 0) diff = -diff;
        int256 diffRatio = diff * Constant.BASIS_POINTS_DIVISOR / Constant.PRICE_PRECISION;
        if (diffRatio < 2e6) return Constant.PRICE_PRECISION;
        else return price;
    }

    function checkDiff(int256 pythPrice, int256 oraclePrice) view private returns(bool) {
        if (oraclePrice == 0) return false;
        int256 priceDiffRatio = pythPrice > oraclePrice ?
            (pythPrice - oraclePrice) * Constant.BASIS_POINTS_DIVISOR / pythPrice :
            (oraclePrice - pythPrice) * Constant.BASIS_POINTS_DIVISOR / pythPrice;

        return priceDiffRatio < maxDiffRatio;
    }

    // get chainlink price
    function getOraclePrice(bytes32 priceId) public view override returns(int256 price) {
        require(oracles[priceId] != address(0), InvalidPriceId());
        
        (, int256 oraclePrice, , , ) = AggregatorV2V3Interface(oracles[priceId]).latestRoundData();
        int256 oraclePriceE10 = adjustPricePrecision(oraclePrice, uint32(oracleDecimals[priceId]), Constant.PRICE_PRECISION);

        if (isStablePrice[priceId]) return getStablePrice(oraclePriceE10);

        return oraclePriceE10;
    }

    function getPythPrice(bytes32 priceId) public view override returns(int256 price) {
        bytes32 pythFeedId = pythFeedIds[priceId];
        require(pythFeedId != bytes32(0), InvalidPriceId());

        PythStructs.Price memory priceInfo = IPyth(pythOracle).getPriceNoOlderThan(pythFeedId, 86400);
        price = adjustPricePrecision(int256(priceInfo.price), uint32(priceInfo.expo>0?priceInfo.expo:-priceInfo.expo), Constant.PRICE_PRECISION);
        if (isStablePrice[priceId]) return getStablePrice(price);
    }

    function getIndexPrice(bytes32 priceId) public view override returns(int256 price) {
        bytes32 pythFeedId = pythFeedIds[priceId];
        require(pythFeedId != bytes32(0), InvalidPriceId());

        
        (, int256 oraclePrice, , uint256 priceTime, ) = AggregatorV2V3Interface(oracles[priceId]).latestRoundData();
        int256 oraclePriceE10 = adjustPricePrecision(oraclePrice, uint32(oracleDecimals[priceId]), Constant.PRICE_PRECISION);
        if (isStablePrice[priceId]) return getStablePrice(oraclePriceE10);

        PythStructs.Price memory priceInfo = IPyth(pythOracle).getPriceNoOlderThan(pythFeedId, pythEffectiveDuration);
        int256 pythPriceE10 = adjustPricePrecision(int256(priceInfo.price), uint32(priceInfo.expo>0?priceInfo.expo:-priceInfo.expo), Constant.PRICE_PRECISION);

        // Validate price validity
        require(block.timestamp - priceInfo.publishTime < pythEffectiveDuration, PriceInactivation(pythPriceE10, priceInfo.publishTime));
        require(block.timestamp - priceTime < oracleEffectiveDuration && checkDiff(pythPriceE10, oraclePriceE10), PythPriceError(pythPriceE10, oraclePriceE10));

        return pythPriceE10;
    }

    function getUpdateFee(bytes[] memory _priceUpdateData) public view returns(uint256 fee) {
        fee = IPyth(pythOracle).getUpdateFee(_priceUpdateData);
    }

    function updatePrice(bytes32[] memory _priceIds, bytes[] memory _priceUpdateData) payable public override {
        uint256 fee = IPyth(pythOracle).getUpdateFee(_priceUpdateData);
        IPyth(pythOracle).parsePriceFeedUpdates{value: fee}(_priceUpdateData, _priceIds, uint64(block.timestamp-pythEffectiveDuration), uint64(block.timestamp));
    }
}