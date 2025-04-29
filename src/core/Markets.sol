// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./interfaces/IMarkets.sol";
import "./interfaces/IPools.sol";
import "./interfaces/IConfigManager.sol";

import "../libraries/Constant.sol";
import "../libraries/Plugin.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract Markets is IMarkets, Plugin {
    address public pools;
    address public configManager;
    bool public paused; // pause any operations

    // marketId => marketConfig
    mapping(bytes32 => MarketConfig) public markets;
    // positionId => position
    mapping(bytes32 => Position) public positions;

    constructor(address _pools, address _configManager) {
        pools = _pools;
        configManager = _configManager;
    }

    function createMarket(address margin, bytes32 pairId) public override returns(bytes32 marketId) {
        require(msg.sender == pools, OnlyPools());
        marketId = keccak256(abi.encode(pairId, margin));
        require(markets[marketId].pairId == bytes32(0), MarketExisted());

        IConfigManager.PairConfig memory pairConfig = IConfigManager(configManager).getPairConfig(pairId);
        require(pairConfig.pairId == pairId, InvalidPair());
        IConfigManager.AssetConfig memory assetConfig = IConfigManager(configManager).getAssetConfig(margin);
        require(assetConfig.token == margin, InvalidMargin());

        markets[marketId] = MarketConfig({
            pairId: pairId,
            margin: margin,
            increasePaused: false,
            decreasePaused: false,
            liquidatePaused: false,
            precision: int256(10**assetConfig.decimals),
            feeRatio: 4e4, // 0.04% 
            imRatio: pairConfig.imRatio,
            mmRatio: pairConfig.mmRatio,
            multiplier: assetConfig.multiplier,
            minimumMargin: assetConfig.minimumMargin,
            dust: pairConfig.dust
        });

        emit CreatedMarket(marketId, margin, pairId, markets[marketId]);
    }

    function updateMarket(bytes32 marketId, MarketConfig memory config) public onlyGov() {
        MarketConfig memory marketConfig = markets[marketId];
        require(marketConfig.margin != address(0), MarketNotExist());

        require(config.imRatio >= 1e5 && config.imRatio <= 1e7, InvalidIM()); 
        require(config.mmRatio >= config.imRatio/5 && config.mmRatio <= config.imRatio/2, InvalidMM()); 
        require(config.minimumMargin >= 1e4, InvalidMinimumMargin());
        require(config.dust >= 1e15, InvalidDust());
        require(config.feeRatio <= 1e5, InvalidFeeRatio());

        config.pairId = marketConfig.pairId;
        config.margin = marketConfig.margin;
        config.increasePaused = marketConfig.increasePaused;
        config.decreasePaused = marketConfig.decreasePaused;
        config.liquidatePaused = marketConfig.liquidatePaused;
        config.precision = marketConfig.precision;
        config.multiplier = marketConfig.multiplier;

        markets[marketId] = config;

        emit UpdatedMarket(marketId, config);
    }

    function updatePausedStatus(bytes32 marketId, bool increasePaused, bool decreasePaused, bool liquidatePaused, bool globalPaused) public onlyGov() {
        MarketConfig memory marketConfig = markets[marketId];
        require(marketConfig.margin != address(0), MarketNotExist());
        if (decreasePaused) require(increasePaused, InvalidPausedStatus());
        if (liquidatePaused) require(decreasePaused, InvalidPausedStatus());

        paused = globalPaused;
        marketConfig.increasePaused = increasePaused;
        marketConfig.decreasePaused = decreasePaused;
        marketConfig.liquidatePaused = liquidatePaused;

        markets[marketId] = marketConfig;

        emit UpdatedPausedStatus(marketId, increasePaused, decreasePaused, liquidatePaused, globalPaused);
    }

    function getPositionId(bytes32 marketId, address taker, bool direction) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(marketId, taker, direction));
    }

    function getMarketConfig(bytes32 marketId) external view override returns(MarketConfig memory) {
        return markets[marketId];
    }
    function getPositionInfo(bytes32 marketId, address taker, bool direction) public view returns(Position memory) {
        return positions[getPositionId(marketId, taker, direction)];
    }

    function increasePosition(IncreasePositionParams memory params) public override returns(int256 tradeValue) {
        require(!paused, Paused());
        MarketConfig memory market = markets[params.marketId];
        require(market.margin != address(0), InvalidMarketId());
        require(params.amount > market.dust, InvalidAmount());
        require(params.margin >= market.minimumMargin, InsufficientMargin());

        if (!params.direction) params.amount = -params.amount;
        
        int256 adjustMargin = params.margin * Constant.PRECISION / market.precision;
        
        bytes32 positionId = getPositionId(params.marketId, params.taker, params.direction);
        Position memory position = positions[positionId];
        
        SafeERC20.safeTransferFrom(IERC20(market.margin), msg.sender, pools, uint256(params.margin));
        
        int256 indexPrice = IPools(pools).getIndexPrice(params.marketId);

        IPools.TradeResult memory result = IPools(pools).trade(IPools.TradeParams({
            poolId: params.marketId,
            amount: params.amount,
            margin: adjustMargin,
            taker: params.taker,
            receiver: params.taker,
            liquidater: params.taker,
            isIncrease: true,
            liquidated: false,
            indexPrice: indexPrice
        }));
        emit SettledFunding(params.marketId, params.taker, position.amount, result.increaseFundingPayment, result.frg);

        require(result.value > adjustMargin, InvalidMargin());

        if (position.taker == address(0)) {
            position.taker = params.taker;
            position.marketId = params.marketId;
        }
        
        position.margin += adjustMargin-result.tradeFee;
        position.amount += result.amount;
        position.value += result.value;
        position.fundingGrowthGlobal = result.frg;
        position.unsettledFundingPayment += result.increaseFundingPayment - result.settledFundingPayment;
        positions[positionId] = position;

        {
            (bool liquidated, ) = _isLiquidatable(LiquidateParams({
                marketId: params.marketId,
                direction: params.direction,
                indexPrice: indexPrice,
                increaseFundingPayment: result.increaseFundingPayment,
                position: position,
                config: market
            }));
            require(!liquidated, PositionDanger());
        }
        

        tradeValue = result.value;
        
        emit IncreasedPosition(params.marketId, params.taker, params.direction, adjustMargin, result.amount, result.value, result.tradeFee);
    }

    function decreasePosition(bytes32 marketId, bool direction, int256 amount) public override returns(int256 marginBalance, int256 tradeValue) {
        (marginBalance, tradeValue) = settlePosition(SettleParams({
            marketId: marketId,
            taker: msg.sender,
            direction: direction,
            amount: amount,
            isLiquidated: false,
            reciver: msg.sender
        }));
    }

    function decreasePosition(bytes32 marketId, address taker, bool direction, int256 amount) public override approved(taker) returns(int256 marginBalance, int256 tradeValue) {
        (marginBalance, tradeValue) = settlePosition(SettleParams({
            marketId: marketId,
            taker: taker,
            direction: direction,
            amount: amount,
            isLiquidated: false,
            reciver: msg.sender
        }));
    }

    function liquidate(bytes32 marketId, address taker, bool direction) public override returns(int256 marginBalance, int256 tradeValue) {
        require(msg.sender != taker, InvalidCall());
        {
            int256 brokePrice = IPools(pools).getBrokeInfo(marketId).indexPrice;
            (bool liquidated, ) = isLiquidatable(marketId, taker, direction);
            require(liquidated || brokePrice > 0, NotLiquidate());
        }

        (marginBalance, tradeValue) = settlePosition(SettleParams({
            marketId: marketId,
            taker: taker,
            direction: direction,
            amount: type(int256).max,
            isLiquidated: true,
            reciver: taker
        }));
    }

    function addMargin(bytes32 marketId, address taker, bool direction, int256 amount) public override {
        require(amount > 0, InvalidAmount());
        require(!paused, Paused());
        require(!markets[marketId].increasePaused, IncreasedPaused());
        bytes32 positionId = getPositionId(marketId, taker, direction);
        Position memory position = positions[positionId];
        require(position.amount != 0, NotPosition());

        int256 adjustMargin = amount * Constant.PRECISION / markets[marketId].precision;
        require(position.value >= position.margin + adjustMargin, ExcessiveMargin());
        positions[positionId].margin += adjustMargin;
        IPools(pools).takerAddMargin(marketId, direction, adjustMargin);

        SafeERC20.safeTransferFrom(IERC20(markets[marketId].margin), msg.sender, pools, uint256(amount));

        emit AddedMargin(marketId, taker, direction, adjustMargin);
    }


    function isLiquidatable(bytes32 marketId, address taker, bool direction) public view override returns (bool liquidated, int256 liquidatePrice) {
        IMarkets.Position memory position;
        {
            bytes32 positionId = getPositionId(marketId, taker, direction);
            position = positions[positionId];
        }
        // calc funding fee
        int256 fundingFee = 0;
        int256 indexPrice = 0;
        {
            int256 frg;
            (, frg, , indexPrice) = IPools(pools).getFundingInfo(marketId);
            fundingFee = position.amount * (frg - position.fundingGrowthGlobal) / Constant.BASIS_POINTS_DIVISOR  / Constant.PRICE_PRECISION;
        }
        (liquidated, liquidatePrice) = _isLiquidatable(LiquidateParams({
            marketId: marketId,
            direction: direction,
            indexPrice: indexPrice,
            increaseFundingPayment: fundingFee,
            position: position,
            config: markets[marketId]
        }));
    }
    struct LiquidateParams {
        bytes32 marketId;
        bool direction;
        int256 indexPrice;
        int256 increaseFundingPayment;
        Position position;
        MarketConfig config;
    }
    function _isLiquidatable(LiquidateParams memory params) private pure returns (bool liquidated, int256 liquidatePrice) {
        if (params.position.amount == 0) return (false, 0);
        int256 amount = abs(params.position.amount);
        
        int d = params.direction ? int256(1) : int256(-1);
        
        if (params.config.multiplier != Constant.BASIS_POINTS_DIVISOR) {
            params.position.margin = params.position.margin * params.config.multiplier / Constant.BASIS_POINTS_DIVISOR;
            params.position.unsettledFundingPayment = params.position.unsettledFundingPayment * params.config.multiplier / Constant.BASIS_POINTS_DIVISOR;
        }

        liquidatePrice = (params.position.value*d - params.position.margin + params.position.unsettledFundingPayment + params.increaseFundingPayment) * Constant.PRICE_PRECISION / 
            (amount*(Constant.BASIS_POINTS_DIVISOR*d - params.config.mmRatio) / Constant.BASIS_POINTS_DIVISOR);
        liquidated = params.indexPrice <= liquidatePrice == params.direction;
    }

    struct SettleParams {
        bytes32 marketId;
        address taker;
        bool direction;
        int256 amount;
        bool isLiquidated;
        address reciver;
    }
    struct SettleVars {
        bytes32 positionId;
        int256 amount;
        int256 indexPrice;
        int256 tradeRatio;
        int256 settledMargin;
        int256 settledValue;
    }
    function settlePosition(SettleParams memory params) private returns (int256 marginBalance, int256 tradeValue) {
        require(params.amount > 0, InvalidAmount());
        SettleVars memory vars;
        vars.positionId = getPositionId(params.marketId, params.taker, params.direction);
        Position memory position = positions[vars.positionId];
        require(position.amount !=0, NotPosition());
        MarketConfig memory marketConfig = markets[params.marketId];

        require(!paused, Paused());
        if (params.isLiquidated) 
            require(!marketConfig.decreasePaused, DecreasePaused());
        else 
            require(!marketConfig.liquidatePaused, LiquidatePaused());

        if (params.direction) vars.amount = -params.amount;
        else vars.amount = params.amount;
        if (abs(position.amount) - abs(params.amount) < marketConfig.dust) {
            vars.amount = -position.amount;
            vars.tradeRatio = Constant.BASIS_POINTS_DIVISOR;
        }
        else {
            vars.tradeRatio = abs(vars.amount * Constant.BASIS_POINTS_DIVISOR / position.amount);
        }

        vars.indexPrice = IPools(pools).getIndexPrice(params.marketId);

        IPools.TradeResult memory result = IPools(pools).trade(IPools.TradeParams({
            poolId: params.marketId,
            amount: vars.amount,
            margin: 0,
            taker: params.taker,
            receiver: params.reciver,
            liquidater: msg.sender,
            isIncrease: false,
            liquidated: params.isLiquidated,
            indexPrice: vars.indexPrice
        }));
        marginBalance = result.marginBalance > 0 ? result.marginBalance : int256(0);

        tradeValue = result.value;
        emit SettledFunding(params.marketId, params.taker, position.amount, result.increaseFundingPayment, result.frg);
        // decrease settled positon
        if (vars.tradeRatio == Constant.BASIS_POINTS_DIVISOR) {
            vars.settledMargin = position.margin;
            vars.settledValue = position.value;
            position.margin = 0;
            position.amount = 0;
            position.value = 0;
            position.unsettledFundingPayment = 0;
            position.fundingGrowthGlobal = 0;
        } else {
            vars.settledMargin = position.margin * vars.tradeRatio / Constant.BASIS_POINTS_DIVISOR;
            vars.settledValue = position.value * vars.tradeRatio / Constant.BASIS_POINTS_DIVISOR;            
            position.margin -= vars.settledMargin; 
            position.amount += vars.amount; 
            position.value -= vars.settledValue; 
            position.fundingGrowthGlobal = result.frg;
            position.unsettledFundingPayment += result.increaseFundingPayment - result.settledFundingPayment;
        }
        
        // update position
        positions[vars.positionId] = position;

        
        if (params.isLiquidated) {
            emit LiquidatedPosition(params.marketId, params.taker, params.direction, vars.settledMargin, -vars.amount, vars.settledValue, result.tradeFee, result.pnl, result.liquidateFee, result.settledFundingPayment);
        } else {
            emit DecreasedPosition(params.marketId, params.taker, params.direction, vars.settledMargin, -vars.amount, vars.settledValue, result.tradeFee, result.pnl, result.settledFundingPayment);
        }
    }

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }
}