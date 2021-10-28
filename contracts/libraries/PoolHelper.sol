// "SPDX-License-Identifier: UNLICENSED"

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
  ) internal pure returns (uint256 amountIn) {
    if (amountOut == 0) return 0;
    uint256 liq = liqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
    require(liq > 0, 'HAIn');
    if (zeroForOne) {
      amountIn = ((liq * liq) / (reserve1 + (liq * sqrt0) / E18 - amountOut) - (reserve0 + (liq * E18) / sqrt1));
      if(amountIn>0) amountIn++;
    } else {
    amountIn = ((liq * liq) / (reserve0 + (liq * E18) / sqrt1 - amountOut) - (reserve1 + (liq * sqrt0) / E18)); // dim = 0
    if(amountIn>0) amountIn++;
    }
  }

  function AmountOut(
    bool zeroForOne,
    uint256 reserve0,
    uint256 reserve1,
    uint256 sqrt0,
    uint256 sqrt1,
    uint256 amountIn
  ) internal pure returns (uint256 amountOut) {
    if (amountIn == 0) return 0;
    uint256 liq = liqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
    require(liq > 0, 'HAOut');
    if (zeroForOne) {
      amountOut = ((reserve1 + (liq * sqrt0) / E18) - (liq * liq) / (reserve0 + (liq * E18) / sqrt1 + amountIn));
      if(amountOut > 1) amountOut--;
    } else{
      amountOut =  ((reserve0 + (liq * E18) / sqrt1) - (liq * liq) / (reserve1 + (liq * sqrt0) / E18 + amountIn));
      if(amountOut > 1) amountOut--;
    }
  }
}
