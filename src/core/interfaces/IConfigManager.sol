// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;
import "./IMatchingEngine.sol";

interface IConfigManager {
    // Used for add liquidity or as position margin
    struct AssetConfig {
        address token;   // asset token address
        uint8 decimals;
        bool isStable;   
        bytes32 pythFeedId;
        int256 multiplier;  // The value of the asset: 1e8
        int256 minimumMargin; // minimum for add liquidity or as position margin: asset limit 
        int256 makerLimit;  // capital limit for market making: 1e20
        string symbol;
    }

    struct PairConfig {
        bytes32 pairId;
        bytes32 pythFeedId;
        int256 imRatio;  // initial margin ratio
        int256 mmRatio;  // maintenance margin ratio
        int256 reserveRatio;
        int256 dust;        // 1e20
        string pair;
    }

    error InvalidMultiplier();
    error InvalidPythFeedId();
    error InvalidIM();
    error InvalidMM();
    error InvalidMinimumMargin();
    error InvalidDust();
    error InvalidMakerLimit();

    error InvalidReserveRatio();

    error AssetNotExist();
    error AssetExisted();

    error PairNotExist();
    error PairExisted();

    error ConfigTooMuch();
    error InvalidId();
    error InvalidTickConfig();

    event AddedAsset(
        address indexed token, 
        uint8 decimals, 
        bool isStable, 
        int256 multiplier, 
        bytes32 pythFeedId, 
        int256 minimumMargin,
        int256 makerLimit,
        string symbol
    );
    event UpdatedAsset(
        address indexed token, 
        int256 multiplier, 
        bytes32 pythFeedId, 
        int256 minimumMargin,
        int256 makerLimit
    );
    event AddedPair(
        bytes32 indexed pairId,
        int256 imRatio,
        int256 mmRatio,
        bytes32 pythFeedId,
        int256 reserveRatio,
        int256 dust,
        string pair
    );
    event UpdatedPair(
        bytes32 indexed pairId,
        int256 im,
        int256 mm,
        bytes32 pythFeedId,
        int256 reserveRatio,
        int256 dust,
        string pair
    );

    event AddedTickConfig(uint8 indexed poolId, IMatchingEngine.TickConfig[] config);
    event UpdatedTickConfig(uint8 indexed poolId, IMatchingEngine.TickConfig[] config);


    function assetsList() external view returns(address[] memory);
    function pairsList() external view returns(bytes32[] memory);

    function getAssetConfig(address asset) external view returns(AssetConfig memory assetConfig);
    function getPairConfig(bytes32 pairId) external view returns(PairConfig memory pairConfig);
    function getTickConfigNum() external view returns(uint256);
    function getTickConfig(uint8 id) external view returns(IMatchingEngine.TickConfig[] memory config);
}