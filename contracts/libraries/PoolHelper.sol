/*******************************************************
 * Copyright (C) 2021-2022 Konrad Wierzbik <desired.desire@protonmail.com>
 *
 * This file is part of DesireSwapProject.
 *
 * DesireSwapProject can not be copied and/or distributed without the express
 * permission of Konrad Wierzbik
 *******************************************************/
pragma solidity ^0.8.0;

library PoolHelper {
  uint256 private constant DD = 10**36;
  uint256 private constant D = 10**18;
  uint256 private constant d = 10**9;

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
    uint256 b = (x * sqrt0) / D + (y * D) / sqrt1;
    uint256 _sqrt = sqrt(b**2 + 4 * ((x * y * (D - (sqrt0 * D) / sqrt1)) / D));
    return (((b + _sqrt) * D) / (2 * (D - (D * sqrt0) / sqrt1)));
  }

  function AmountIn(
    bool zeroForOne,
    uint256 reserve0,
    uint256 reserve1,
    uint256 sqrt0,
    uint256 sqrt1,
    uint256 amountOut
  ) internal pure returns (uint256) {
    uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
    require(L > 0, 'Try different amounts');
    if (zeroForOne) {
      return ((L * L) / (reserve1 + (L * sqrt0) / D - amountOut) - (reserve0 + (L * D) / sqrt1)); //dim = 0
    } else return ((L * L) / (reserve0 + (L * D) / sqrt1 - amountOut) - (reserve1 + (L * sqrt0) / D)); // dim = 0
  }

  function AmountOut(
    bool zeroForOne,
    uint256 reserve0,
    uint256 reserve1,
    uint256 sqrt0,
    uint256 sqrt1,
    uint256 amountIn
  ) internal pure returns (uint256) {
    uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
    require(L > 0, 'Try different amounts');
    if (zeroForOne) {
      return ((reserve1 + (L * sqrt0) / D) - (L * L) / (reserve0 + (L * D) / sqrt1 + amountIn));
    }
    return ((reserve0 + (L * D) / sqrt1) - (L * L) / (reserve1 + (L * sqrt0) / D + amountIn));
  }

  /* UNUSED
    function currentSqrtPrice(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256)
    {
      // first calculate Lq Coef with higher pecision
      uint256 b = (x * sqrt0) + (y * DD) / sqrt1;
      uint256 _sqrt = sqrt(b**2 + 4 * ((x * y * (DD - (sqrt0 * DD) / sqrt1))));
      uint256 L = (((b + _sqrt) * D) / (2 * (D - (D * sqrt0) / sqrt1)));
      return (L/(reserve1 + L*sqrt0/D));
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

  // returns amount of token1 in that would be in range if all token0 were taken out
  /*UNUSED
    function inToken1Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 inToken1Supply)
    {
        uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        inToken1Supply = (reserve0*reserve1*D**3/sqrt1/L + reserve0*D**2*sqrt0/sqrt1)/D**2 + reserve1;
    }
    */
}
