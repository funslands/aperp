// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "./interfaces/IConfigManager.sol";
import "./interfaces/IMarkets.sol";
import "./interfaces/IPools.sol";
import "./interfaces/IMatchingEngine.sol";
import "./interfaces/IPriceHelper.sol";
import "./interfaces/IInsuranceManager.sol";
import "../staking/interfaces/IStaker.sol";
import "../libraries/Constant.sol";
import "../libraries/Plugin.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract Pools is IPools, Plugin {
    address public markets;
    address public configManager;
    address public priceHelper;
    address public matchingEngine;
    address public insurance;
    address public staker;
    address public WETH;

    bool public paused; // pause any operations

    int256 public miningRewardRatio = 5e7; // 50%
    int256 public fundingCalcInterval = 900; // 15min


    // poolId => poolConfig
    mapping (bytes32=> PoolConfig) public poolsConfig;

    // makerPosition
    // poolId => trader=> maker position
    mapping(bytes32=> mapping(address=> Position)) public makerPositions;
    // poolId => global maker position
    mapping(bytes32=> PoolStatus) public globalPosition;

    // taderInfo
    // poolId => traders position info 0: shortStatus 1: longStatus
    mapping(bytes32=> PoolStatus[2]) public poolStatus; 
    // poolId => funding fees
    mapping(bytes32=> int256) public unsettledFundingPayment; // funding fees for trader's unsettled positions

    mapping(bytes32=> int256) public fundingRatioGrowthGlobal;

    mapping(bytes32=> uint256) public lastFundingTime;

    mapping(address=> uint256) public rewardAmounts;
    // Upon the pool’s bankruptcy, liquidate all positions and liquidity at that price
    mapping(bytes32=> PoolInfo) private brokeInfo;

    function setConfig(
        address _markets, 
        address _configManager, 
        address _priceHelper, 
        address _matchingEngine, 
        address _insurance,
        address _staker,
        address _WETH,
        int256 _fundingCalcInterval
    ) public onlyGov() {
        require(_fundingCalcInterval > 600 && _fundingCalcInterval < 28800, InvalidInterval()); // 10min - 8h
        markets = _markets;
        configManager = _configManager;
        priceHelper = _priceHelper;
        matchingEngine = _matchingEngine;
        insurance = _insurance;
        fundingCalcInterval = _fundingCalcInterval;
        WETH = _WETH;
        staker = _staker;

        emit SetConfig(_markets, _configManager, _priceHelper, _matchingEngine, _insurance, _WETH, _staker, _fundingCalcInterval);
    }

    function getPoolConfig(bytes32 poolId) public view override returns(PoolConfig memory config) {
        return poolsConfig[poolId];
    }

    function getPosition(bytes32 poolId, address maker) external view override returns(Position memory position) {
        return makerPositions[poolId][maker];
    }

    function createPool(bytes32 pairId, address asset, int256 amount, uint8 tickConfigId) public returns(bytes32 poolId) {
        poolId = keccak256(abi.encode(pairId, asset));
        require(poolsConfig[poolId].asset == address(0), PoolExisted());

        IConfigManager.PairConfig memory pairConfig = IConfigManager(configManager).getPairConfig(pairId);
        require(pairConfig.pairId == pairId, InvalidPair());
        IConfigManager.AssetConfig memory assetConfig = IConfigManager(configManager).getAssetConfig(asset);
        require(assetConfig.token == asset, InvalidAsset());

        int256 assetPrice = IPriceHelper(priceHelper).getIndexPrice(bytes32(uint256(uint160(asset))));
        require(assetPrice != 0, ErrorPrice());
        // initial liquidity greater than 100k USD
        int256 precision = int256(10 ** assetConfig.decimals);
        require(assetPrice * amount / precision >= 100000*Constant.PRICE_PRECISION, InsufficientAmount());

        poolsConfig[poolId] = PoolConfig({
            precision: precision,
            asset: asset,
            imRatio: pairConfig.imRatio*2,
            mmRatio: pairConfig.mmRatio,
            pairId: pairConfig.pairId,
            reserveRatio: pairConfig.reserveRatio, 
            makerLimit: assetConfig.makerLimit,
            minimumMargin: assetConfig.minimumMargin,
            feeRatio: 1e5, // 0.1% 
            multiplier: assetConfig.multiplier,
            dust: assetConfig.minimumMargin*Constant.PRECISION/precision/100,
            addPaused: false,
            removePaused: false,
            liquidatePaused: false
        });

        IMarkets(markets).createMarket(asset, pairId);
        // config match engine 
        IMatchingEngine.TickConfig[] memory tickConfig = IConfigManager(configManager).getTickConfig(tickConfigId);
        IMatchingEngine(matchingEngine).updateTickConfig(poolId, tickConfig);

        IInsuranceManager(insurance).updatePoolConfig(poolId, asset, uint256(assetConfig.minimumMargin/10));

        int256 lpAmount = amount * Constant.PRECISION / precision;
        addLiquidity(poolId, msg.sender, amount, lpAmount);
        makerPositions[poolId][msg.sender].initial = true;

        emit CreatedPool(poolId, poolsConfig[poolId], amount, tickConfigId);
    }

    function updatePoolConfig(bytes32 poolId, PoolConfig memory config) public onlyGov() {
        PoolConfig memory poolConfig = poolsConfig[poolId];
        require(poolConfig.asset != address(0), PoolNotExist());
        require(config.reserveRatio >= 1e7 && config.reserveRatio <= 5e7, InvalidReserveRatio());
        require(config.imRatio >= 1e5 && config.imRatio <= 1e7, InvalidIM()); 
        require(config.mmRatio >= config.imRatio/5 && config.mmRatio <= config.imRatio/2, InvalidMM()); 
        require(config.minimumMargin >= 1e4, InvalidMinimumMargin());
        require(config.dust >= 1e15, InvalidDust());
        require(config.makerLimit >= 1e20, InvalidMakerLimit());
        require(config.feeRatio <= 1e5, InvalidFeeRatio());

        config.asset = poolConfig.asset;
        config.precision = poolConfig.precision;
        config.multiplier = poolConfig.multiplier;
        config.pairId = poolConfig.pairId;
        config.addPaused = poolConfig.addPaused;
        config.removePaused = poolConfig.removePaused;
        config.liquidatePaused = poolConfig.liquidatePaused;

        poolsConfig[poolId] = config;

        emit UpdatedPoolConfig(poolId, config);
    }

    function updatePausedStatus(bytes32 poolId, bool addPaused, bool removePaused, bool liquidatePaused, bool globalPaused) public onlyGov() {
        PoolConfig memory poolConfig = poolsConfig[poolId];
        require(poolConfig.asset != address(0), PoolNotExist());
        if (removePaused) require(addPaused, InvalidPausedStatus());
        if (liquidatePaused) require(removePaused, InvalidPausedStatus());

        paused = globalPaused;
        poolConfig.addPaused = addPaused;
        poolConfig.removePaused = removePaused;
        poolConfig.liquidatePaused = liquidatePaused;

        poolsConfig[poolId] = poolConfig;

        emit UpdatedPausedStatus(poolId, addPaused, removePaused, liquidatePaused, globalPaused);
    }

    function poolUnrealizedPnl(bytes32 poolId, int256 price) private view returns(int256 pnl) {
        PoolStatus memory longStatus = poolStatus[poolId][1];
        PoolStatus memory shortStatus = poolStatus[poolId][0];

        if (longStatus.amount == shortStatus.amount) return 0;

        pnl = (shortStatus.amount-longStatus.amount)*price/Constant.PRICE_PRECISION - (shortStatus.value - longStatus.value);
        
        if (poolsConfig[poolId].multiplier != Constant.BASIS_POINTS_DIVISOR)
            pnl = pnl * Constant.BASIS_POINTS_DIVISOR / poolsConfig[poolId].multiplier;
    }

    function getFundInfo(bytes32 poolId) public view returns(int256 makerFund, int256 limitFund, int256 availableFund) {
        if (globalPosition[poolId].value == 0) return (0, 0, 0);
        limitFund = globalPosition[poolId].value * (Constant.BASIS_POINTS_DIVISOR-poolsConfig[poolId].reserveRatio) / Constant.BASIS_POINTS_DIVISOR;
        int256 makerlimit = poolsConfig[poolId].makerLimit;
        makerFund = limitFund > makerlimit ? makerlimit : limitFund;

        int256 multiplier = poolsConfig[poolId].multiplier;
        availableFund = globalPosition[poolId].value - (poolStatus[poolId][0].value + poolStatus[poolId][1].value) * Constant.BASIS_POINTS_DIVISOR / multiplier;
        if (multiplier != Constant.BASIS_POINTS_DIVISOR) 
            makerFund = makerFund * multiplier / Constant.BASIS_POINTS_DIVISOR; 
    }

    function getOraclePrice(bytes32 poolId) public view override returns(int256) {
        return IPriceHelper(priceHelper).getOraclePrice(poolsConfig[poolId].pairId);
    }

    function getIndexPrice(bytes32 poolId) public view override returns(int256) {
        return IPriceHelper(priceHelper).getIndexPrice(poolsConfig[poolId].pairId);
    }

    function getMarketPrice(bytes32 poolId, int256 indexPrice) public view override returns(int256) {
        bytes32 pairId = poolsConfig[poolId].pairId;
        if (indexPrice == 0) indexPrice = IPriceHelper(priceHelper).getOraclePrice(pairId);
        return IMatchingEngine(matchingEngine).getMarketPrice(
            poolId, 
            indexPrice
        );
    }

    function getNetValue(bytes32 poolId) public view override returns(int256) {
        return poolInfo(poolId, false, false).netValue;
    }

    function poolInfo(bytes32 poolId, bool isMarketPrice, bool accurate) public view returns(PoolInfo memory pi) {
        bytes32 pairId = poolsConfig[poolId].pairId;
        pi.indexPrice = accurate ?
            IPriceHelper(priceHelper).getIndexPrice(pairId) :
            IPriceHelper(priceHelper).getOraclePrice(pairId);
        int256 price = pi.indexPrice;
        if (isMarketPrice) {
            pi.marketPrice = getMarketPrice(poolId, price);
            price = pi.marketPrice;
        }
        if (globalPosition[poolId].amount == 0) {
            pi.netValue = Constant.PRICE_PRECISION;
            return pi;
        }
        pi.pnl = poolUnrealizedPnl(poolId, price);
        (, , pi.fundingFee) = _getFundingInfo(poolId, pi.indexPrice);
        // pool value 
        int256 poolValue = globalPosition[poolId].value + pi.pnl + unsettledFundingPayment[poolId] + pi.fundingFee;
        pi.netValue = poolValue * Constant.PRICE_PRECISION / globalPosition[poolId].amount;
    }

    /**
     * @dev add liquidity
     * @param margin asset deimals
     * @param amount liquidity amount: 1e20
     */
    function addLiquidity(bytes32 poolId, address maker, int256 margin, int256 amount) public override returns(int256 addAmount) {
        PoolConfig memory poolConfig = poolsConfig[poolId];
        require(!paused, Paused());
        require(!poolConfig.addPaused, AddPaused());
        require(margin >= poolConfig.minimumMargin, InsufficientMargin());

        PoolInfo memory pi = poolInfo(poolId, false, true);
        {
            (bool liquidated, ) = _isLiquidatable(poolId, maker, pi);
            require(!liquidated, Liquidated());
        }
        // transfer margin
        SafeERC20.safeTransferFrom(IERC20(poolConfig.asset), msg.sender, address(this), uint256(margin));

        _updateFunding(poolId, pi.indexPrice);

        // adjust decimals
        margin = margin*Constant.PRECISION / poolConfig.precision;
        require(amount >= margin, InvalidAmount());
        int256 value = amount * pi.netValue / Constant.PRICE_PRECISION;
        require(margin*Constant.BASIS_POINTS_DIVISOR/value >= poolConfig.imRatio, PositionDanger());

        Position storage position = makerPositions[poolId][maker];

        if (position.initial && position.increaseTime + 30 days < block.timestamp) position.initial = false;

        // update maker position
        position.amount += amount;
        position.margin += margin;
        position.value += value;
        position.increaseTime = block.timestamp;

        // update global maker position
        globalPosition[poolId].amount += amount;
        globalPosition[poolId].margin += margin;
        globalPosition[poolId].value += value;

        addAmount = amount;

        (int256 makerFund, ,) = getFundInfo(poolId);
        IMatchingEngine(matchingEngine).updateFund(poolId, makerFund, pi.indexPrice);
        emit AddedLiquidity(maker, poolId, amount, value, margin, pi.netValue);
    }

    function removeLiquidity(bytes32 poolId, int256 amount) public returns(int256 marginBalance, int256 removeAmount) {
        PoolInfo memory pi = poolInfo(poolId, true, true);
        (marginBalance, removeAmount) = settlePosition(SettleParams({
            poolId: poolId,
            maker: msg.sender,
            liquidated: false,
            amount: amount,
            receiver: msg.sender,
            pi: pi
        }));
    }

    /// @notice This is a dangerous operation, please authorize carefully
    function removeLiquidity(bytes32 poolId, address maker, int256 amount, address receiver) public override approved(maker) returns(int256 marginBalance, int256 removeAmount) {
        PoolInfo memory pi = poolInfo(poolId, true, true);
        (marginBalance, removeAmount) = settlePosition(SettleParams({
            poolId: poolId,
            maker: maker,
            liquidated: false,
            amount: amount,
            receiver: receiver,
            pi: pi
        }));
    }

    function addMargin(bytes32 poolId, address maker, int256 margin) public override {
        Position memory position = makerPositions[poolId][maker];
        PoolConfig memory poolConfig = poolsConfig[poolId];

        // adjust decimals
        margin = margin * Constant.PRECISION / poolConfig.precision;
        require(!paused, Paused());
        require(position.amount > 0, NotPosition());
        require(
            position.margin + margin >= position.amount,
            ExcessiveMargin()
        );

        SafeERC20.safeTransferFrom(IERC20(poolConfig.asset), msg.sender, address(this), uint256(margin));


        makerPositions[poolId][maker].margin += margin;
        globalPosition[poolId].margin += margin;

        emit AddedMargin(maker, poolId, margin);
    }

    function liquidate(bytes32 poolId, address maker) public override returns(int256 marginBalance, int256 liquidateAmount) {
        require(msg.sender != maker, InvalidCall());
        PoolInfo memory pi = poolInfo(poolId, false, true);
        {
            (bool liquidated, ) = _isLiquidatable(poolId, maker, pi);
            require(liquidated, NotLiquidate());
        }

        (marginBalance, liquidateAmount) = settlePosition(SettleParams({
            poolId: poolId,
            maker: maker,
            liquidated: true,
            amount: type(int256).max,
            receiver: maker,
            pi: pi
        }));
    }

    struct SettleParams {
        bytes32 poolId;
        address maker;
        bool liquidated;
        int256 amount;    // liquidity amount: 1e20
        address receiver; // receiver address of the balance margin
        PoolInfo pi;     // pool info
    }
    struct DecreasePositionVars {
        int256 tradeRatio;
        int256 tradeValue;
        int256 settledValue;
        int256 settledMargin;
        int256 pnl;
        int256 removeFee;
        int256 liquidateReward;
        int256 insuranceFund;
        int256 makerFund;
        int256 availableFund;
    }
    function settlePosition(SettleParams memory params) private returns(int256 marginBalance, int256 removeAmount) {
        if (brokeInfo[params.poolId].indexPrice > 0) {
            require(params.liquidated, Broked());
            params.pi = brokeInfo[params.poolId];
        }
        Position memory position = makerPositions[params.poolId][params.maker];
        
        require(position.amount > 0, NotPosition());
        if (position.initial)
            require(position.increaseTime + 30 days < block.timestamp, PositionLocked(position.increaseTime + 30 days));
        PoolConfig memory poolConfig = poolsConfig[params.poolId];
        require(params.amount > poolConfig.dust, InvalidAmount());
        require(!paused, Paused());
        if (params.liquidated)
            require(!poolConfig.liquidatePaused, LiquidatePaused());
        else
            require(!poolConfig.removePaused, RemovePaused());

        _updateFunding(params.poolId, params.pi.indexPrice);

        if (position.amount - params.amount <= poolConfig.dust) params.amount = position.amount;

        DecreasePositionVars memory vars;
        vars.tradeRatio = params.amount * Constant.BASIS_POINTS_DIVISOR / position.amount;
        vars.settledMargin = position.margin * vars.tradeRatio / Constant.BASIS_POINTS_DIVISOR;

        vars.tradeValue = params.amount * params.pi.netValue / Constant.PRICE_PRECISION;
        (vars.pnl, vars.settledValue) = calcPnl(position.value, vars.tradeValue, vars.tradeRatio, true);
        (vars.makerFund, , vars.availableFund) = getFundInfo(params.poolId);
        if (!params.liquidated)
            require(vars.availableFund-vars.tradeValue >= 0, InsufficientLiquidity());

        (marginBalance, vars.removeFee, vars.insuranceFund, vars.liquidateReward) = calcFees(CalcFeesParams({
            poolId: params.poolId,
            settledMargin: vars.settledMargin,
            settledValue: vars.settledValue,
            pnl: vars.pnl,
            feeRatio: poolConfig.feeRatio,
            mmRatio: poolConfig.mmRatio,
            tradeFee: 0,
            fundingFee: 0,
            liquidated: params.liquidated,
            increaseTime: position.increaseTime,
            multiplier: Constant.BASIS_POINTS_DIVISOR
        }));

        vars.insuranceFund += vars.removeFee;
        // update maker position 
        position.amount -= params.amount;
        position.margin -= vars.settledMargin;
        position.value  -= vars.settledValue;
        if (position.initial && position.amount == 0) position.initial = false;
        makerPositions[params.poolId][params.maker] = position;

        // update global maker position
        globalPosition[params.poolId].amount -= params.amount;
        globalPosition[params.poolId].margin -= vars.settledMargin+vars.pnl;
        globalPosition[params.poolId].value  -= vars.tradeValue; 

        settleFund(SettleFundParams({
            poolId: params.poolId,
            liquidated: params.liquidated,
            receiver: params.receiver,
            liquidater: msg.sender,
            marginBalance: marginBalance,
            insuranceFund: vars.insuranceFund,
            liquidateReward: vars.liquidateReward
        }));

        // adjust decimals
        marginBalance = marginBalance * poolConfig.precision / Constant.PRECISION;
        if (marginBalance < 0) marginBalance = 0; 
        

        (vars.makerFund, ,) = getFundInfo(params.poolId);
        removeAmount = params.amount;
        IMatchingEngine(matchingEngine).updateFund(params.poolId, vars.makerFund, params.pi.indexPrice);
        if (params.liquidated) {
            emit LiquidatedLiquidity(msg.sender, params.maker, params.poolId, params.amount, vars.settledValue, vars.settledMargin, params.pi.netValue, vars.pnl, vars.insuranceFund+vars.liquidateReward);
        }
        else {
            emit RemovedLiquidity(params.maker, params.poolId, params.amount, vars.settledValue, vars.settledMargin, params.pi.netValue, vars.pnl, vars.removeFee);
        }
    }

    struct CalcFeesParams {
        bytes32 poolId;
        int256 settledMargin;
        int256 settledValue;
        int256 pnl;
        int256 feeRatio;
        int256 mmRatio;
        int256 tradeFee;
        int256 fundingFee;
        bool liquidated;
        uint256 increaseTime;
        int256 multiplier;
    }
    function calcFees(CalcFeesParams memory params) private view returns(int256 marginBalance, int256 tradeFee, int256 insuranceFund, int256 liquidateReward) {
        // remove fee used for insurance
        int256 removeFeeRatio = params.feeRatio;
        if (params.tradeFee > 0) {
            tradeFee = params.tradeFee;
        }
        else {
            if (params.liquidated || params.increaseTime + 7 days < block.timestamp) removeFeeRatio = 0;

            if (removeFeeRatio > 0) {
                tradeFee = params.settledValue * removeFeeRatio / Constant.BASIS_POINTS_DIVISOR;
            }
        }

        marginBalance = params.settledMargin + params.pnl - params.fundingFee;
        if (marginBalance <= 0) {
            tradeFee = 0;
        }
        else if (marginBalance > 0 && marginBalance < tradeFee) {
            marginBalance = 0;
            tradeFee = marginBalance;
        }
        else {
            marginBalance -= tradeFee;
            if (params.liquidated) {
                int256 liquidateFee = params.settledValue * params.mmRatio / Constant.BASIS_POINTS_DIVISOR / 4;
                if (params.multiplier != Constant.BASIS_POINTS_DIVISOR) 
                    liquidateFee = liquidateFee * Constant.BASIS_POINTS_DIVISOR / params.multiplier;
                if (liquidateFee >= marginBalance) {
                    insuranceFund += marginBalance;
                    marginBalance = 0;
                }
                else {
                    insuranceFund += liquidateFee;
                    marginBalance -= liquidateFee;
                    if (liquidateFee >= marginBalance) {
                        liquidateReward = marginBalance;
                        marginBalance = 0;
                    }
                    else {
                        liquidateReward = liquidateFee;
                        marginBalance -= liquidateFee;
                    }
                }
            }
        }
    }

    struct SettleFundParams {
        bytes32 poolId;
        bool liquidated;
        address receiver;
        address liquidater;
        int256 marginBalance;
        int256 insuranceFund;
        int256 liquidateReward;
    }
    function settleFund(SettleFundParams memory params) private {
        // use insurance fund 
        if (params.marginBalance < 0) {
            require(params.liquidated, PositionLiquidated());
            uint256 adjustMarginBalance = uint256(-params.marginBalance * poolsConfig[params.poolId].precision / Constant.PRECISION);
            IInsuranceManager(insurance).useInsurance(params.poolId, adjustMarginBalance);
        }
        if (params.marginBalance > 0) {
            uint256 adjustMarginBalance = uint256(params.marginBalance * poolsConfig[params.poolId].precision / Constant.PRECISION);
            SafeERC20.safeTransfer(IERC20(poolsConfig[params.poolId].asset), params.receiver, adjustMarginBalance);
        }

        // add insurance fund
        if (params.insuranceFund > 0) {
            uint256 adjustInsuranceFund = uint256(params.insuranceFund * poolsConfig[params.poolId].precision / Constant.PRECISION);
            SafeERC20.safeTransfer(IERC20(poolsConfig[params.poolId].asset), insurance, adjustInsuranceFund);
            IInsuranceManager(insurance).addInsurance(params.poolId, adjustInsuranceFund);
        }
        
        if (params.liquidated) {
            if (params.liquidateReward > 0) {
                uint256 adjustLiquidateReward = uint256(params.liquidateReward * poolsConfig[params.poolId].precision / Constant.PRECISION);
                SafeERC20.safeTransfer(IERC20(poolsConfig[params.poolId].asset), params.liquidater, adjustLiquidateReward);
            }
            IInsuranceManager(insurance).liquidaterReward(params.poolId, params.liquidater);
        }
    }

    function calcPnl(int256 positionValue, int256 tradeValue, int256 tradeRatio, bool direction) private pure returns(int256 pnl, int256 settledValue) {
        settledValue = tradeRatio == Constant.BASIS_POINTS_DIVISOR ? positionValue : positionValue*tradeRatio/Constant.BASIS_POINTS_DIVISOR;
        pnl = tradeValue - settledValue;
        if (!direction) pnl = -pnl;
    }

    function isBroke(bytes32 poolId) public view override returns(bool broked, int256 brokeNetValue) {
        PoolInfo memory pi = poolInfo(poolId, false, false);
        (broked, brokeNetValue) = _isBroke(poolId, pi);
    }

    function _isBroke(bytes32 poolId, PoolInfo memory pi) private view returns(bool broked, int256 brokeNetValue) {
        if (brokeInfo[poolId].indexPrice > 0) return (true, pi.netValue);
        PoolStatus memory position = globalPosition[poolId];
        if (position.amount == 0) return (false, 0);

        brokeNetValue = (position.value - position.margin - unsettledFundingPayment[poolId] - pi.fundingFee) * Constant.PRICE_PRECISION / 
            (position.amount*(Constant.BASIS_POINTS_DIVISOR-poolsConfig[poolId].mmRatio)/Constant.BASIS_POINTS_DIVISOR);
        broked = pi.netValue <= brokeNetValue;
    }

    function getBrokeInfo(bytes32 poolId) public view returns(PoolInfo memory info) {
        return brokeInfo[poolId];
    }

    function isLiquidatable(bytes32 poolId, address maker) public view override returns(bool liquidated, int256 liquidateNetValue) {
        PoolInfo memory pi = poolInfo(poolId, false, false);
        (liquidated, liquidateNetValue) = _isLiquidatable(poolId, maker, pi);
    }

    function _isLiquidatable(bytes32 poolId, address maker, PoolInfo memory pi) private view returns(bool liquidated, int256 liquidateNetValue) {
        (liquidated, liquidateNetValue) = _isBroke(poolId, pi);
        if (liquidated) return (true, liquidateNetValue);
        Position memory position = makerPositions[poolId][maker];
        if (position.amount == 0) return (false, 0);

        liquidateNetValue = (position.value - position.margin) * Constant.PRICE_PRECISION / 
            (position.amount*(Constant.BASIS_POINTS_DIVISOR-poolsConfig[poolId].mmRatio)/Constant.BASIS_POINTS_DIVISOR);
        liquidated = pi.netValue <= liquidateNetValue;
    }

    function broke(bytes32 poolId) public {
        PoolInfo memory pi = poolInfo(poolId, false, true);
        (bool broked,) = _isBroke(poolId, pi);
        require(broked, NotBroke());
        brokeInfo[poolId] = pi;
        _updateFunding(poolId, pi.indexPrice);

        IInsuranceManager(insurance).brokeReward(poolId, msg.sender);
        emit PoolBroked(poolId, msg.sender, pi.indexPrice);
    }

    function restorePool(bytes32 poolId) public {
        require(brokeInfo[poolId].indexPrice > 0, NotBroke());
        require(
            globalPosition[poolId].amount ==0 &&
            poolStatus[poolId][0].amount ==0 &&
            poolStatus[poolId][1].amount ==0,
            Unrestorable()
        );
        brokeInfo[poolId].indexPrice = 0;
        brokeInfo[poolId].netValue = 0;
        int256 poolMargin = globalPosition[poolId].margin;
        PoolConfig memory config = poolsConfig[poolId];
        if (poolMargin > config.dust) {
            uint256 adjustMargin = uint256(poolMargin*config.precision/Constant.PRECISION);
            SafeERC20.safeTransfer(IERC20(config.asset), insurance, adjustMargin);
            IInsuranceManager(insurance).addInsurance(poolId, adjustMargin);
        }
        if (poolMargin != 0) {
            globalPosition[poolId].margin = 0;
            globalPosition[poolId].value = 0;
        }

        IInsuranceManager(insurance).brokeReward(poolId, msg.sender);
        emit PoolRestored(poolId, msg.sender);
    }

    struct TradeVars {
        int256 availableFund;
        int256 indexPrice;
        int256 tradeRatio;
        int256 settledValue;
        int256 settledMargin;
        int256 insuranceFund;
        int256 liquidateReward;
    }
    function trade(TradeParams memory params) public override returns(TradeResult memory result) {
        require(msg.sender == markets, OnlyMarkets());
        if (brokeInfo[params.poolId].indexPrice > 0) {
            require(params.liquidated, Broked());
            params.indexPrice = brokeInfo[params.poolId].indexPrice;
        }
        TradeVars memory vars;
        IMarkets.MarketConfig memory config = IMarkets(markets).getMarketConfig(params.poolId);
        IMarkets.Position memory position = IMarkets(markets).getPositionInfo(params.poolId, params.taker, params.isIncrease == params.amount > 0);
        result.frg = _updateFunding(params.poolId, params.indexPrice);

        result.increaseFundingPayment = position.amount * (result.frg-position.fundingGrowthGlobal) / Constant.BASIS_POINTS_DIVISOR  / Constant.PRICE_PRECISION;

        
        (, , vars.availableFund) = getFundInfo(params.poolId);

        (result.amount, result.value, ) = IMatchingEngine(matchingEngine).matching(
            IMatchingEngine.MatchingParams({
                poolId: params.poolId,
                tradeAmount: params.amount,
                price: params.indexPrice
            })
        );
        if (params.liquidated) {
            result.amount = abs(params.amount);
            result.value = result.amount * params.indexPrice / Constant.PRICE_PRECISION;
        }

        result.tradeFee = result.value*config.feeRatio / Constant.BASIS_POINTS_DIVISOR; 
        if (config.multiplier != Constant.BASIS_POINTS_DIVISOR) {
            result.tradeFee = result.tradeFee * Constant.BASIS_POINTS_DIVISOR / config.multiplier;
            result.increaseFundingPayment = result.increaseFundingPayment * Constant.BASIS_POINTS_DIVISOR / config.multiplier;
        }

        if (params.isIncrease) {
            require(params.margin * config.multiplier / result.value > config.imRatio, PositionDanger());
            if (config.multiplier != Constant.BASIS_POINTS_DIVISOR) {
                vars.availableFund = vars.availableFund * config.multiplier / Constant.BASIS_POINTS_DIVISOR;
            }
            require(vars.availableFund >= result.value, InsufficientLiquidity());
            if (params.amount > 0) {
                poolStatus[params.poolId][1].amount += result.amount;
                poolStatus[params.poolId][1].value += result.value;
                poolStatus[params.poolId][1].margin += params.margin-result.tradeFee;
            }
            else {
                poolStatus[params.poolId][0].amount += result.amount;
                poolStatus[params.poolId][0].value += result.value;
                poolStatus[params.poolId][0].margin += params.margin-result.tradeFee;
            }
        }
        else { 
            int256 pa = abs(position.amount);
            if (result.amount == pa) {
                vars.settledMargin = position.margin;
                vars.settledValue = position.value;
                vars.tradeRatio = Constant.BASIS_POINTS_DIVISOR;
            }
            else {
                vars.tradeRatio = result.amount * Constant.BASIS_POINTS_DIVISOR / pa; 
                vars.settledValue = position.value * vars.tradeRatio / Constant.BASIS_POINTS_DIVISOR;
                vars.settledMargin = position.margin * vars.tradeRatio / Constant.BASIS_POINTS_DIVISOR;
            }

            if (params.amount < 0) {
                poolStatus[params.poolId][1].amount -= result.amount;
                poolStatus[params.poolId][1].value -= vars.settledValue;
                poolStatus[params.poolId][1].margin -= vars.settledMargin;
            }
            else {
                poolStatus[params.poolId][0].amount -= result.amount;
                poolStatus[params.poolId][0].value -= vars.settledValue;
                poolStatus[params.poolId][0].margin -= vars.settledMargin;
            }

            (result.pnl, ) = calcPnl(position.value, result.value, vars.tradeRatio, position.amount > 0);
            result.settledFundingPayment = (position.unsettledFundingPayment+result.increaseFundingPayment) * vars.tradeRatio / Constant.BASIS_POINTS_DIVISOR;
            int256 adjustSettledValue = vars.settledValue;
            
            if (config.multiplier != Constant.BASIS_POINTS_DIVISOR) {
                result.pnl = result.pnl * Constant.BASIS_POINTS_DIVISOR / config.multiplier;
                adjustSettledValue = adjustSettledValue * Constant.BASIS_POINTS_DIVISOR / config.multiplier;
            }
            // pnl limit
            if (result.pnl - result.settledFundingPayment > adjustSettledValue) 
                result.pnl = adjustSettledValue + result.settledFundingPayment;
            
            globalPosition[params.poolId].value += -result.pnl+result.settledFundingPayment;
            globalPosition[params.poolId].margin -= result.pnl;
            unsettledFundingPayment[params.poolId] -= result.settledFundingPayment;

            (result.marginBalance, result.tradeFee, vars.insuranceFund, vars.liquidateReward) = calcFees(CalcFeesParams({
                poolId: params.poolId,
                settledMargin: vars.settledMargin,
                settledValue: vars.settledValue, 
                pnl: result.pnl,
                feeRatio: config.feeRatio,
                mmRatio: config.mmRatio,
                tradeFee: result.tradeFee,
                fundingFee: result.settledFundingPayment,
                liquidated: params.liquidated,
                increaseTime: 0,
                multiplier: config.multiplier
            }));

            result.liquidateFee = vars.liquidateReward + vars.insuranceFund;
            settleFund(SettleFundParams({
                poolId: params.poolId,
                liquidated: params.liquidated,
                receiver: params.receiver,
                liquidater: params.liquidater,
                marginBalance: result.marginBalance,
                insuranceFund: vars.insuranceFund,
                liquidateReward: vars.liquidateReward
            }));
            // adjust decimals
            result.marginBalance = result.marginBalance * config.precision / Constant.PRECISION;   
        }

        if (result.tradeFee > 0) {
            int256 fee = result.tradeFee/2;
            globalPosition[params.poolId].value += fee;
            globalPosition[params.poolId].margin += fee;
            rewardAmounts[config.margin] += uint256(result.tradeFee-fee);
        }
        result.amount = params.amount;
        emit Traded(params.poolId, params.taker, params.isIncrease, params.amount, result.value, result.pnl, result.tradeFee, result.settledFundingPayment);
    }

    function takerAddMargin(bytes32 poolId, bool direction, int256 amount) external override {
        require(msg.sender == markets, OnlyMarkets());
        if (direction) poolStatus[poolId][1].margin += amount;
        else poolStatus[poolId][0].margin += amount;
    }

    function getFundingInfo(bytes32 poolId) public view override returns(int256 fundingRatio, int256 frg, int256 fundingFee, int256 indexPrice) {
        indexPrice = IPriceHelper(priceHelper).getOraclePrice(poolsConfig[poolId].pairId);
        (fundingRatio, frg, fundingFee) = _getFundingInfo(poolId, indexPrice);
    }

    struct FundingVars {
        int256 usageRatio;
        int256 passedInterval;
        int256 diffPosition;
        int256 FRG;
    }
    function _getFundingInfo(bytes32 poolId, int256 price) private view returns(int256 fundingRatio, int256 frg, int256 fundingFee) {
        FundingVars memory vars;
        PoolStatus memory longStatus = poolStatus[poolId][1];
        PoolStatus memory shortStatus = poolStatus[poolId][0];
        vars.FRG = fundingRatioGrowthGlobal[poolId];

        vars.usageRatio = IMatchingEngine(matchingEngine).getStatus(poolId).usageRatio;
        
        fundingRatio = 1e4; // 0.01%/8h
        if (shortStatus.amount < longStatus.amount) {
            if (vars.usageRatio <= 10e6) fundingRatio= 1e4;
            else if (vars.usageRatio <= 40e6) fundingRatio = 1e4 + (vars.usageRatio - 10e6)/300;
            else fundingRatio = 110000 + (vars.usageRatio - 40e6)/100;
        }
        else {
            if (vars.usageRatio <= 4e6) fundingRatio= 1e4;
            else if (vars.usageRatio <= 40e6) fundingRatio = 1e4 + (4e6 - vars.usageRatio)/300;
            else fundingRatio = -110000+ (40e6 - vars.usageRatio)/100;
        }
        
        vars.passedInterval = int256(block.timestamp - lastFundingTime[poolId]) / fundingCalcInterval;
        if (vars.passedInterval == 0) return (fundingRatio, vars.FRG, 0);
        frg = fundingRatio * price * vars.passedInterval * fundingCalcInterval / 28800; // 8h 
        

        vars.diffPosition = longStatus.amount - shortStatus.amount;
        if (vars.diffPosition == 0) return (fundingRatio, vars.FRG, 0);
        fundingFee = frg * vars.diffPosition / Constant.BASIS_POINTS_DIVISOR / Constant.PRICE_PRECISION; 

        if (poolsConfig[poolId].multiplier != Constant.BASIS_POINTS_DIVISOR)
            fundingFee = fundingFee * Constant.BASIS_POINTS_DIVISOR / poolsConfig[poolId].multiplier;

        frg = vars.FRG + frg;
    }

    function updateFunding(bytes32 poolId) public override returns(int256 frg) {
        int256 indexPrice = IPriceHelper(priceHelper).getOraclePrice(poolsConfig[poolId].pairId);
        frg = _updateFunding(poolId, indexPrice);
    }

    function _updateFunding(bytes32 poolId, int256 price) private returns(int256 frg) {
        uint256 currentTime = block.timestamp;
        uint256 updateTime = currentTime - currentTime % uint256(fundingCalcInterval); 
        if (lastFundingTime[poolId] == 0 || brokeInfo[poolId].indexPrice > 0) {
            lastFundingTime[poolId] = updateTime;
            return fundingRatioGrowthGlobal[poolId];
        }
        int256 fundingRatio;
        int256 fundingFee;
        (fundingRatio, frg, fundingFee) = _getFundingInfo(poolId, price);
        if (updateTime == lastFundingTime[poolId]) return frg;
        
        fundingRatioGrowthGlobal[poolId] = frg; // 8h
        unsettledFundingPayment[poolId] += fundingFee;
        lastFundingTime[poolId] = updateTime;

        emit UpdatedFundingRatio(poolId, fundingRatio, frg, fundingFee);
    }

    function swapReward(address asset) public override returns(uint256 inputAmount, uint256 outputAmount) {
        if (staker == address(0)) return (0, 0);
        uint256 discount = 0;
        {
            uint256 interval = block.timestamp % 1 days;
            require(interval < 3600, SwapPaused());
            discount = 1e5 + 9e5 * interval / 3600; // 0.1% - 1%
        }
        uint256 amount = rewardAmounts[asset];
        if (asset == WETH) {
            amount = amount * 1e18 / uint256(Constant.PRECISION);
            outputAmount = amount*discount/1e8;
            SafeERC20.safeTransfer(IERC20(WETH), msg.sender, outputAmount);
            SafeERC20.forceApprove(IERC20(WETH), staker, amount-outputAmount);
            IStaker(staker).addReward(amount-outputAmount);
        }
        else {
            uint256 decimals = IConfigManager(configManager).getAssetConfig(asset).decimals;
            outputAmount = amount*10**decimals / uint256(Constant.PRECISION);
            int256 assetPrice = IPriceHelper(priceHelper).getOraclePrice(bytes32(uint256(uint160(asset))));
            int256 ethPrice = IPriceHelper(priceHelper).getOraclePrice(bytes32(uint256(uint160(WETH))));
            SafeERC20.safeTransfer(IERC20(asset), msg.sender, outputAmount);
            inputAmount = amount*(1e8-discount)*uint256(assetPrice)/uint256(ethPrice)/1e8;
            inputAmount = inputAmount * 1e18 / uint256(Constant.PRECISION);
            SafeERC20.safeTransferFrom(IERC20(WETH), msg.sender, address(this), inputAmount);
            SafeERC20.forceApprove(IERC20(WETH), staker, inputAmount);
            IStaker(staker).addReward(inputAmount);
        }
    }

    function abs(int256 x) private pure returns(int256) {
        return x >= 0 ? x : -x;
    }
}