// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface ILiquidityManagerHelper {
  ///@notice Returns liqToAdd in order to supply amount0 of token 0. also retruns amount1 of token1 needed to supply
  function token0Supply(
    address tokenA,
    address tokenB,
    uint256 fee,
    uint256 amount0,
    int24 lowestRangeIndex,
    int24 highestRangeIndex
  ) external view returns (uint256 liqToAdd, uint256 amount1);

  /// @notice Returns liqToAdd in order to supply amount1 of token 1. also retruns amount0 of token0 needed to supply
  function token1Supply(
    address tokenA,
    address tokenB,
    uint256 fee,
    uint256 amount1,
    int24 lowestRangeIndex,
    int24 highestRangeIndex
  ) external view returns (uint256 liqToAdd, uint256 amount0);
}
