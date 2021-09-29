// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @title Returns prediceted outcome for given swap
interface ISwapRouterHelper {
  function swapQuoter(
    address tokenA,
    address tokenB,
    uint256 fee,
    bool zeroForOne,
    int256 amount,
    uint256 sqrtPriceLimit
  ) external view returns (int256, int256);
}
