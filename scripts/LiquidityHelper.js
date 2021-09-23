const {BigNumber} = require('@ethersproject/bignumber');


module.exports.token0ToLiquidity = function( token0ToAdd, lowestIndexToAdd, highestIndexToAdd, currentPrice, multiplier){
    token0ToAdd = BigNumber.from(token0ToAdd);
    const s0 = multiplier**(lowestIndexToAdd);
    const s1 = multiplier **(highestIndexToAdd);
    const sc = Math.sqrt(currentPrice);
    if(s1<=sc)
        return token0ToAdd.mul(s0*s1/(s1-s0));
    else if (s0<sc && sc < s1)
        return token0ToAdd.mul(s0*sc/(sc-s0));
    else(sc<=s0)
        return "Supply_only_token1";
}

module.exports.token1ToLiquidity = function(token1ToAdd, lowestIndexToAdd, highestIndexToAdd, currentPrice, multiplier){
    token1ToAdd = BigNumber.from(token1ToAdd);
    const s0 = multiplier**(lowestIndexToAdd);
    const s1 = multiplier **(highestIndexToAdd);
    const sc = Math.sqrt(currentPrice);
    if(s1<=sc)
        return "Supply_only_token0";
    else if (s0<sc && sc < s1)
        return (token1ToAdd.div(sc-s0));
    else(sc<=s0)
        return (token1ToAdd.div(s1-s0));
}

module.exports.liquidityToToken0 = function(liquidity, lowestIndexToAdd, highestIndexToAdd, currentPrice, multiplier){
    liquidity = BigNumber.from(liquidity);
    const s0 = multiplier**(lowestIndexToAdd);
    const s1 = multiplier **(highestIndexToAdd);
    const sc = Math.sqrt(currentPrice);
    if(sc<=s0)
        return "Supply_only_token1";
    else if (s0<sc && sc < s1)
        return liquidity.mul((sc-s0)/(sc*s0));
    if(s1<=sc)
        return liquidity.mul((s1-s0)/(s1*s0));    
}

module.exports.liquidityToToken1 = function(liquidity, lowestIndexToAdd, highestIndexToAdd, currentPrice, multiplier){
    liquidity = BigNumber.from(liquidity);
    const s0 = multiplier**(lowestIndexToAdd);
    const s1 = multiplier **(highestIndexToAdd);
    const sc = Math.sqrt(currentPrice);
    if(sc<=s0)
        return liquidity.mul(s1-s0);
    else if (s0<sc && sc < s1)
        return liquidity.mul(sc-s0);
    if(s1<=sc)
        return "Supply_only_token0";    
}
