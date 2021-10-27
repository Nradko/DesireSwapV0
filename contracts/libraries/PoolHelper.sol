/*******************************************************
 * Copyright (C) 2021-2022 Konrad Wierzbik <desired.desire@protonmail.com>
 *
 * This file is part of DesireSwapProject and was developed by Konrad Konrad Wierzbik.
 *
 * DesireSwapProject files that are said to be developed by Konrad Wierzbik can not be copied 
 * and/or distributed without the express permission of Konrad Wierzbik.
 *******************************************************/
pragma solidity ^0.8.0;

library PoolHelper {
  uint256 private constant E36 = 10**36;
  uint256 private constant E18 = 10**18;

  function sqrt(uint256 y) internal pure returns (uint256 z) {
    if (y > 3) {
      z = y;
      uint256 x = y / 2 + 1;
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

  //  "real LiqCoef"
  function liqCoefficient(
    uint256 x,
    uint256 y,
    uint256 sqrt0,
    uint256 sqrt1
  ) internal pure returns (uint256) {
    uint256 b = (x * sqrt0) / E18 + (y * E18) / sqrt1;
    uint256 _sqrt = sqrt(b**2 + 4 * ((x * y * (E18 - (sqrt0 * E18) / sqrt1)) / E18));
    return (((b + _sqrt) * E18) / (2 * (E18 - (E18 * sqrt0) / sqrt1)));
  }

  function AmountIn(
    bool zeroForOne,
    uint256 reserve0,
    uint256 reserve1,
    uint256 sqrt0,
    uint256 sqrt1,
    uint256 amountOut
  ) internal pure returns (uint256) {
    uint256 liq = liqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
    require(liq > 0, 'Try different amounts');
    if (zeroForOne) {
      return ((liq * liq) / (reserve1 + (liq * sqrt0) / E18 - amountOut) - (reserve0 + (liq * E18) / sqrt1)); //dim = 0
    } else return ((liq * liq) / (reserve0 + (liq * E18) / sqrt1 - amountOut) - (reserve1 + (liq * sqrt0) / E18)); // dim = 0
  }

  function AmountOut(
    bool zeroForOne,
    uint256 reserve0,
    uint256 reserve1,
    uint256 sqrt0,
    uint256 sqrt1,
    uint256 amountIn
  ) internal pure returns (uint256) {
    uint256 liq = liqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
    require(liq > 0, 'Try different amounts');
    if (zeroForOne) {
      return ((reserve1 + (liq * sqrt0) / E18) - (liq * liq) / (reserve0 + (liq * E18) / sqrt1 + amountIn));
    }
    return ((reserve0 + (liq * E18) / sqrt1) - (liq * liq) / (reserve1 + (liq * sqrt0) / E18 + amountIn));
  }

  /* UNUSED
    function currentSqrtPrice(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256)
    {
      // first calculate Lq Coef with higher pecision
      uint256 b = (x * sqrt0) + (y * E36) / sqrt1;
      uint256 _sqrt = sqrt(b**2 + 4 * ((x * y * (E36 - (sqrt0 * E36) / sqrt1))));
      uint256 liq = (((b + _sqrt) * E18) / (2 * (E18 - (E18 * sqrt0) / sqrt1)));
      return (liq/(reserve1 + liq*sqrt0/E18));
    }
    */
  // returns amount of token0 in that would be in range if all token0 were taken out

  /* UNUSED
    function inToken0Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 inToken0Supply)
    {
        uint256 liq = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        inToken0Supply = ((sqrt1*reserve0*reserve1*E18)/liq + reserve1*sqrt0*sqrt1)/E18**2 + reserve0;
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
        uint256 liq = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        inToken0Value = reserve0 + (liq*liq/(reserve0 + liq/sqrt1)**2)*reserve1/10**36;
    }
    */

  // returns amount of token1 in that would be in range if all token0 were taken out
  /*UNUSED
    function inToken1Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 inToken1Supply)
    {
        uint256 liq = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        inToken1Supply = (reserve0*reserve1*E18**3/sqrt1/liq + reserve0*E18**2*sqrt0/sqrt1)/E18**2 + reserve1;
    }
    */
}
