// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library PoolHelper {

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
                }
        } else if (y != 0) {
        z = 1;
        }
    }

    function abs(int24 x) internal pure returns (int24) {
    return x >= 0 ? x : -x;
    }


    // returns 10**18 * "real LiqCoef"
    function LiqCoefficient (
        uint256 x, uint256 y,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256)
    {
        //sqrtprice is 10**18*sqrt_real_price
        uint256 DD = 10**36;
        uint256 D = 10**18;
        uint256 b = x*sqrt0 + y*DD/sqrt1;
        return (b + sqrt(b^2 + 4*(DD-(sqrt0*DD)/sqrt1)*x*y))*D/(2*(D-(sqrt0*D)/sqrt1));
    }

    function currentPrice(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 currentPrice)
    {
        uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        currentPrice = (L*L/(reserve0 + L/sqrt1)**2)*reserve1;
    }

    function amountIn(
        bool zeroForOne,
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1,
        uint256 amountOut, uint256 L)
        internal pure
        returns(uint256)
    {
        uint256 D = 10**18;
        if( zeroForOne) 
            return L**2/(reserve1 + L*sqrt0/10**36 - amountOut) - reserve0;
        else
            return L**2/(reserve0 + L/sqrt1 - amountOut) - reserve1;
    }

    function amountOut(
        bool zeroForOne,
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1,
        uint256 amountIn, uint256 L)
        internal pure
        returns(uint256)
    {
        if (zeroForOne)
            return reserve1 - L**2/(reserve0 + L/sqrt1 + amountIn)/10**36;
        else
            return reserve1 - L**2/(reserve1 + L*sqrt0/10**36 + amountIn)/10**36;
        
    }
    */

    // returns amount of token0 in that would be in position if all token0 were taken out
    /* UNUSED
    function inToken0Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1,
        uint256 L)
        internal pure
        returns (uint256 inToken0Supply)
    {
        uint256 D = 10**18;
        inToken0Supply = ((sqrt1*reserve0*reserve1*D)/L + reserve1*sqrt0*sqrt1)/D**2 + reserve0;
    } */

    /* UNUSED
    function inToken0Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 inToken0Supply)
    {
        uint256 D = 10**18;
        uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        inToken0Supply = ((sqrt1*reserve0*reserve1*D)/L + reserve1*sqrt0*sqrt1)/D**2 + reserve0;
    }
    */

    // currentPrice *10**36
    /*UNUSED
    function inToken0Value(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 inToken0Value)
    {
        uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        inToken0Value = reserve0 + (L*L/(reserve0 + L/sqrt1)**2)*reserve1/10**36;
    }
    */

    // returns amount of token1 in that would be in position if all token0 were taken out
    /*UNUSED
    function inToken1Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 inToken1Supply)
    {
        uint256 D = 10**18;
        uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        inToken1Supply = (reserve0*reserve1*D**3/sqrt1/L + reserve0*D**2*sqrt0/sqrt1)/D**2 + reserve1;
    }
    */
    /* UNUSED
    function inToken1Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1,
        uint256 L)
        internal pure
        returns (uint256 inToken1Supply)
    {
        uint256 D = 10**18;
        inToken1Supply = (reserve0*reserve1*D**3/sqrt1/L + reserve0*D**2*sqrt0/sqrt1)/D**2 + reserve1;
    }
    */
}