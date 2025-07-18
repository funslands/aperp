// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "../libraries/Governable.sol";
import "../libraries/Constant.sol";
import "./interfaces/IMatchingEngine.sol";

contract MatchingEngine is IMatchingEngine, Governable {
    address public pools;
    // poolId => ticks
    mapping (bytes32=> TickAmount[]) public ticks;
    // poolId => status
    mapping (bytes32=> PoolStatus) public status;

    modifier onlyPools() {
        require(msg.sender == pools, OnlyPools());
        _;
    }

    constructor(address _pools) {
        pools = _pools;
    }

    function checkTickConfig(TickConfig[] memory config) public pure override returns(bool) {
        uint256 length = config.length;
        if (length < 3 || length > 10) return false;

        if (
            config[0].usageRatio != 0 ||
            config[0].slippage < 0 ||
            config[length-1].usageRatio != Constant.BASIS_POINTS_DIVISOR ||
            config[length-1].slippage > Constant.BASIS_POINTS_DIVISOR
        ) return false;
        
        int256 usageRatio = config[0].usageRatio;
        int256 slippage = config[0].slippage;
        for (uint256 i = 1; i < length; i++) {
            if(
                config[i].usageRatio <= usageRatio ||
                config[i].slippage <= slippage
            ) return false;
            usageRatio = config[i].usageRatio;
            slippage = config[i].slippage;
        }
        return true;
    }

    function updateTickConfig(bytes32 poolId, TickConfig[] memory config) public override {
        require(
            msg.sender == pools ||  // create pool
            msg.sender == gov, // update config
            InvalidCall()
        );
        require(checkTickConfig(config), InvalidTickConfig());
        uint256 ln = config.length;
        uint256 lo = ticks[poolId].length;
        uint256 len = ln > lo ? ln : lo;

        PoolStatus memory s = status[poolId];
        int256 tickAmount = 0;
        for (uint256 i = 0; i < len; i++) {
            if (ln<=i) {
                ticks[poolId].pop();
            }
            else {
                if (i<s.currentTick) {
                    if (i<lo) tickAmount = ticks[poolId][i].amount;
                }
                else {
                    if (s.makerAmount > 0) {
                        tickAmount = s.makerAmount * config[i].usageRatio / Constant.BASIS_POINTS_DIVISOR;
                    }
                }
                TickAmount memory tick = TickAmount({
                    usageRatio: config[i].usageRatio,
                    slippage: config[i].slippage,
                    amount: tickAmount
                });
                if (i<lo) ticks[poolId][i] = tick;
                else ticks[poolId].push(tick);
            }
            
            
        }
        PoolStatus memory result = calcStatus(poolId, s.position, s.makerAmount);
        if (result.currentTick > s.currentTick) s.currentTick = result.currentTick;
        s.makerAmount = result.makerAmount;

        status[poolId] = s;

        emit UpdatedPool(poolId, config);
    }

    function getStatus(bytes32 poolId) public view override returns(PoolStatus memory) {
        return status[poolId];
    }

    function updateFund(bytes32 poolId, int256 amount, int256 price) public override onlyPools {
        uint256 len = ticks[poolId].length;
        require(len > 2, InvalidPool());
        PoolStatus memory s = status[poolId];
        int256 makerAmount = amount * Constant.PRICE_PRECISION / price;
        int256 p = abs(s.position);
        if (p > makerAmount) makerAmount = p;
        
        for (uint256 i = s.currentTick; i < len; i++) {
            ticks[poolId][i].amount = makerAmount * ticks[poolId][i].usageRatio / Constant.BASIS_POINTS_DIVISOR;
        }

        PoolStatus memory result = calcStatus(poolId, s.position, makerAmount);
        if (result.currentTick > s.currentTick) s.currentTick = result.currentTick;
        s.makerAmount = result.makerAmount;
        s.usageRatio = result.usageRatio;

        status[poolId] = s;

        emit UpdatedFund(poolId, makerAmount, price);
    }

    function getPoolConf(bytes32 poolId) public view returns(TickAmount[] memory) {
        return ticks[poolId];
    }

    function getMarketPrice(bytes32 poolId, int256 price) public override view returns(int256 marketPrice) {
        PoolStatus memory s = status[poolId];

        if (s.slippage == 0) return price;
        if (s.position > 0)
            marketPrice = price * (Constant.BASIS_POINTS_DIVISOR + s.slippage) / Constant.BASIS_POINTS_DIVISOR;
        else 
            marketPrice = price * (Constant.BASIS_POINTS_DIVISOR - s.slippage) / Constant.BASIS_POINTS_DIVISOR;
    }

    struct MatchingVars {
        uint256 length;
        int256 tradeAmount;
        int256 positionAmount;
        int256 extraAmount;
        uint256 initTick;
        TickAmount lastTick;
        TickAmount currentTick;
    }
    function matching(MatchingParams memory params) public override onlyPools() returns(int256 amount, int256 value, int256 price) {
        MatchingVars memory vars;
        vars.length = ticks[params.poolId].length;

        PoolStatus memory s = status[params.poolId];
        StepResult memory result;

        vars.tradeAmount = params.tradeAmount > 0 ? params.tradeAmount : -params.tradeAmount;
        vars.positionAmount = abs(s.position);

        
        // decrease position
        if (params.tradeAmount * s.position < 0) {
            require(s.makerAmount + vars.positionAmount >= vars.tradeAmount, LiquidityShortage(vars.tradeAmount, s.makerAmount + vars.positionAmount));

            int256 makerAmount0 = vars.positionAmount * 5e6 / Constant.BASIS_POINTS_DIVISOR; // 5%
            vars.extraAmount = vars.positionAmount - makerAmount0;
            
            result = stepMatching(StepParams(
                vars.tradeAmount, 
                s.position > 0, 
                false,
                ticks[params.poolId][0], 
                TickAmount(s.usageRatio, s.slippage, 0),
                makerAmount0,
                params.price
            ));

            if (result.complete) {
                s.position += params.tradeAmount;
                
                status[params.poolId] = calcStatus(params.poolId, s.position, s.makerAmount);
                updateTickAmount(params.poolId, s.currentTick);

                return (result.amount, result.value, result.value * Constant.PRICE_PRECISION / result.amount);
            }
            else {
                vars.initTick = s.currentTick;
                s.currentTick = 0;
                vars.tradeAmount -= result.amount;
                vars.lastTick = ticks[params.poolId][0];
                amount += result.amount;
                value += result.value;
            }
        }
        else { // increase position
            require(vars.tradeAmount <= s.makerAmount-vars.positionAmount, LiquidityShortage(vars.tradeAmount, s.makerAmount-vars.positionAmount));
            vars.lastTick.usageRatio = s.usageRatio;
            vars.lastTick.slippage = s.slippage;
            vars.lastTick.amount = vars.positionAmount;
        }

        if (vars.extraAmount != 0 && abs(vars.tradeAmount) >= abs(vars.extraAmount)) {
            TickAmount memory tick = ticks[params.poolId][1];
            tick.amount = s.makerAmount * tick.usageRatio / Constant.BASIS_POINTS_DIVISOR;
            ticks[params.poolId][1] = tick;
        }

        if (s.currentTick == 0) s.currentTick = 1;
        for (uint256 i = s.currentTick; i < vars.length; i++) {
            vars.currentTick = ticks[params.poolId][i];
            if (!result.complete) {
                result = stepMatching(StepParams(
                    vars.tradeAmount, 
                    params.tradeAmount > 0, 
                    true,
                    vars.lastTick,
                    vars.currentTick, 
                    vars.extraAmount,
                    params.price
                ));

                amount += result.amount;
                value += result.value;
                vars.tradeAmount -= result.amount;
                if (result.complete) {
                    s.position += params.tradeAmount;
                    if (vars.extraAmount != 0) {
                        status[params.poolId] = calcStatus(params.poolId, s.position, s.makerAmount);
                        updateTickAmount(params.poolId, vars.initTick);
                    }
                    else {
                        s.currentTick = i;
                        s.slippage = result.slippage;
                        s.usageRatio = abs(s.position) * Constant.BASIS_POINTS_DIVISOR / s.makerAmount;
                        status[params.poolId] = s;
                    }
                    return (amount, value, value * Constant.PRICE_PRECISION / amount);
                }
                if (vars.extraAmount != 0) vars.extraAmount = 0;
            }
            vars.lastTick = vars.currentTick;
        }

        require(result.complete, LiquidityShortage(amount, s.makerAmount));
    }

    struct StepParams {
        int256 tradeAmount;
        bool positionDirection;
        bool increase;
        TickAmount lastTick;
        TickAmount currentTick;
        int256 extraAmount;
        int256 price;
    }
    struct StepResult {
        bool complete;
        int256 amount;
        int256 value;
        int256 slippage;
    }
    // stepMatching
    function stepMatching(StepParams memory params) private pure returns(StepResult memory result) {
        int256 tickAmount = params.extraAmount + params.currentTick.amount-params.lastTick.amount;
        int256 avgSlippage;
        if (tickAmount >= params.tradeAmount) {
            result.amount = params.tradeAmount;
            int256 tradeRatio = result.amount * Constant.BASIS_POINTS_DIVISOR / tickAmount;
            
            if (params.increase) {
                result.slippage = params.lastTick.slippage + (params.currentTick.slippage - params.lastTick.slippage) * tradeRatio / Constant.BASIS_POINTS_DIVISOR;
                avgSlippage = (result.slippage + params.lastTick.slippage) / 2;
            }
            else {
                result.slippage = params.currentTick.slippage - (params.currentTick.slippage - params.lastTick.slippage) * tradeRatio / Constant.BASIS_POINTS_DIVISOR;
                avgSlippage = (result.slippage + params.currentTick.slippage) / 2;
            }
            
            result.complete = true;
        }
        else {
            result.amount = tickAmount;
            result.slippage = params.currentTick.slippage;
            avgSlippage = (params.currentTick.slippage + params.lastTick.slippage) / 2;
            result.complete = false;
        }

        

        if (params.positionDirection) {
            result.value = result.amount * params.price * (Constant.BASIS_POINTS_DIVISOR + avgSlippage) / Constant.PRICE_PRECISION / Constant.BASIS_POINTS_DIVISOR;
        }
        else {
            result.value = result.amount * params.price * (Constant.BASIS_POINTS_DIVISOR - avgSlippage) / Constant.PRICE_PRECISION / Constant.BASIS_POINTS_DIVISOR;
        }

    }

    function calcStatus(bytes32 poolId, int256 position, int256 makerAmount) private view returns(PoolStatus memory s) {
        s.makerAmount = makerAmount;
        int256 p = abs(position);
        if (p < 1e15) return s;
        s.position = position;
        uint256 len = ticks[poolId].length;
        if (p == makerAmount) {
            s.currentTick = len;
            s.slippage = ticks[poolId][len-1].slippage;
            s.usageRatio = Constant.BASIS_POINTS_DIVISOR;
            return s;
        }
        for (uint256 i=1; i<len; i++) {
            TickAmount memory current = ticks[poolId][i];
            TickAmount memory last = ticks[poolId][i-1];
            if (p > last.amount && p < current.amount) {
                s.currentTick = i;
                s.slippage = last.slippage + (current.slippage-last.slippage)*(p-last.amount)/(current.amount-last.amount);
                s.usageRatio = p * Constant.BASIS_POINTS_DIVISOR / makerAmount;
                return s;
            }
        }
    }

    function updateTickAmount(bytes32 poolId, uint256 currentTick) private {
        PoolStatus memory s = status[poolId];
        if (s.currentTick >= currentTick) return;
        uint256 diff = currentTick-s.currentTick;
        for (uint256 i=0; i<diff; i++) {
            uint256 t = s.currentTick+i;
            if (t == 0) continue;
            TickAmount memory tick = ticks[poolId][t];
            tick.amount = s.makerAmount * tick.usageRatio / Constant.BASIS_POINTS_DIVISOR;
            ticks[poolId][t] = tick;
        }
    }

    function abs(int256 n) private pure returns(int256) {
        return n > 0 ? n : -n;
    }
}