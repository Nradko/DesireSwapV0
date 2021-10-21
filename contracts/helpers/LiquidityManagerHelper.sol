/*******************************************************
 * Copyright (C) 2021-2022 Konrad Wierzbik <desired.desire@protonmail.com>
 *
 * This file is part of DesireSwapProject.
 *
 * DesireSwapProject can not be copied and/or distributed without the express
 * permission of Konrad Wierzbik
 *******************************************************/
pragma solidity ^0.8.0;

import '../libraries/PoolHelper.sol';
import '../interfaces/IDesireSwapV0Pool.sol';
import '../interfaces/IDesireSwapV0Factory.sol';
import '../interfaces/ILiquidityManagerHelper.sol';

import 'hardhat/console.sol';

contract LiquidityManagerHelper is ILiquidityManagerHelper {
  uint256 private constant D = 10**18;
  uint256 private constant d = 10**9;

  address public immutable factory;

  function getPoolAddress(
    address tokenA,
    address tokenB,
    uint256 fee
  ) private view returns (address) {
    return IDesireSwapV0Factory(factory).poolAddress(tokenA, tokenB, fee);
  }

  constructor(address factory_) {
    factory = factory_;
  }

  struct RangeInfo {
    uint256 reserve0;
    uint256 reserve1;
    uint256 sqrtPriceBottom;
    uint256 sqrtPriceTop;
    uint256 supplyCoefficient;
    bool activated;
  }

  function getFullRangeInfo(address poolAddress, int24 index) public view returns (RangeInfo memory rangeInfo) {
    (uint256 reserve0, uint256 reserve1, uint256 sqrtPriceBottom, uint256 sqrtPriceTop, uint256 supplyCoefficient, bool activated) = IDesireSwapV0Pool(poolAddress).getFullRangeInfo(index);
    rangeInfo = RangeInfo({reserve0: reserve0, reserve1: reserve1, sqrtPriceBottom: sqrtPriceBottom, sqrtPriceTop: sqrtPriceTop, supplyCoefficient: supplyCoefficient, activated: activated});
  }

  function sqrtPriceCurrent(address poolAddress) public view returns (uint256 sqrtPrice) {
    int24 inUseRange = IDesireSwapV0Pool(poolAddress).inUseRange();
    RangeInfo memory r = getFullRangeInfo(poolAddress, inUseRange);
    //   console.log("cp");
    //   console.log(r.reserve0);
    //   console.log(r.reserve1);
    //   console.log(r.sqrtPriceBottom);
    //   console.log(r.sqrtPriceTop);
    uint256 L = PoolHelper.LiqCoefficient(r.reserve0, r.reserve1, r.sqrtPriceBottom, r.sqrtPriceTop);
    //   console.log(L);
    sqrtPrice = PoolHelper.sqrt((L * L) / (r.reserve0 + (L * D) / r.sqrtPriceTop)**2) * D;
  }

  function token0Supply(
    address tokenA,
    address tokenB,
    uint256 fee,
    uint256 amount0,
    int24 lowestRangeIndex,
    int24 highestRangeIndex
  ) public view override returns (uint256 liqToAdd, uint256 amount1) {
    address poolAddress = getPoolAddress(tokenA, tokenB, fee);
    (uint256 amount0Help, uint256 amount1Help) = supply(poolAddress, lowestRangeIndex, highestRangeIndex);
    liqToAdd = (D * d * amount0) / amount0Help;
    amount1 = (amount1Help * amount0) / amount0Help;
  }

  function token1Supply(
    address tokenA,
    address tokenB,
    uint256 fee,
    uint256 amount1,
    int24 lowestRangeIndex,
    int24 highestRangeIndex
  ) public view override returns (uint256 liqToAdd, uint256 amount0) {
    address poolAddress = getPoolAddress(tokenA, tokenB, fee);
    (uint256 amount0Help, uint256 amount1Help) = supply(poolAddress, lowestRangeIndex, highestRangeIndex);
    // console.log(amount0Help);
    // console.log(amount1Help);
    liqToAdd = (D * d * amount1) / amount1Help;
    amount0 = (amount0Help * amount1) / amount1Help;
  }

  function supply(
    address poolAddress,
    int24 lowestRangeIndex,
    int24 highestRangeIndex
  ) public view returns (uint256 amount0, uint256 amount1) {
    uint256 liqToAdd = D * d;
    int24 usingRange = IDesireSwapV0Pool(poolAddress).inUseRange();
    RangeInfo memory r;
    if (lowestRangeIndex > usingRange) {
      for (int24 i = highestRangeIndex; i >= lowestRangeIndex; i--) {
        r = getFullRangeInfo(poolAddress, i);
        require(r.activated, 'ranges not activated');
        amount0 += (liqToAdd * D * (r.sqrtPriceTop - r.sqrtPriceBottom)) / (r.sqrtPriceBottom * r.sqrtPriceTop);
      }
    } else if (highestRangeIndex < usingRange) {
      for (int24 i = lowestRangeIndex; i <= highestRangeIndex; i++) {
        r = getFullRangeInfo(poolAddress, i);
        require(r.activated, 'ranges not activated');
        amount1 += (liqToAdd * (r.sqrtPriceTop - r.sqrtPriceBottom)) / D;
      }
    } else {
      for (int24 i = usingRange + 1; i <= highestRangeIndex; i++) {
        r = getFullRangeInfo(poolAddress, i);
        require(r.activated, 'ranges not activated');
        amount0 += (liqToAdd * D * (r.sqrtPriceTop - r.sqrtPriceBottom)) / (r.sqrtPriceBottom * r.sqrtPriceTop);
      }

      for (int24 i = usingRange - 1; i >= lowestRangeIndex; i--) {
        r = getFullRangeInfo(poolAddress, i);
        require(r.activated, 'ranges not activated');
        amount1 += (liqToAdd * (r.sqrtPriceTop - r.sqrtPriceBottom)) / D;
      }

      r = getFullRangeInfo(poolAddress, usingRange);
      uint256 LiqCoefBefore = PoolHelper.LiqCoefficient(r.reserve0, r.reserve1, r.sqrtPriceBottom, r.sqrtPriceTop);
      uint256 amount0ToAdd;
      uint256 amount1ToAdd;
      if (r.reserve0 == 0 && r.reserve1 == 0) {
        amount0ToAdd = (liqToAdd * D * (r.sqrtPriceTop - r.sqrtPriceBottom)) / (r.sqrtPriceBottom * r.sqrtPriceTop) / 2;
        amount1ToAdd = (liqToAdd * (r.sqrtPriceTop - r.sqrtPriceBottom)) / D / 2;
      } else {
        amount0ToAdd = (liqToAdd * r.reserve0) / LiqCoefBefore;
        amount1ToAdd = (liqToAdd * r.reserve1) / LiqCoefBefore;
      }
      amount0 += amount0ToAdd;
      amount1 += amount1ToAdd;
    }
  }
}
