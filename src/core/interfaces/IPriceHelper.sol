// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IPriceHelper {
    error OnlyConfigManager();
    error InvalidCall();
    error InvalidPriceId();
    error InvalidAsset();
    error InvalidPythFeedId();
    error InvalidDecimals();

    error PriceInactivation(int256 pythPrice, uint256 priceTime);
    error PythPriceError(int256 pythPrice, int256 oraclePrice);

    event UpdatedConfig(address configManager, address pythOracle, uint256 pythEffectiveDuration, uint256 oracleEffectiveDuration, int256 maxDiffRatio);
    event AddedPriceFeedId(bytes32 priceId, bytes32 pythFeedId, address oracle);
    event UpdatedPythFeedId(bytes32 priceId, bytes32 pythFeedId);
    event UpdatedOracle(bytes32 priceId, address oracle, uint8 decimals);

    
    function addPriceFeedId(bytes32 priceId, bytes32 pythFeedId, address oracle, bool isStable) external;
    function updatePythFeedId(bytes32 priceId, bytes32 pythFeedId, bool isStable) external;
    function getOraclePrice(bytes32 priceId) external view returns(int256 price);
    function getPythPrice(bytes32 priceId) external view returns(int256 price);
    function getIndexPrice(bytes32 priceId) external view returns(int256 price);
    function updatePrice(bytes32[] memory _priceIds, bytes[] memory _priceUpdateData) payable external;
}