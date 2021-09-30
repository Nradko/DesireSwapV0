// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolImmutables {
  function factory() external view returns (address);

  function token0() external view returns (address);

  function token1() external view returns (address);

  function sqrtRangeMultiplier() external view returns (uint256);

  function feePercentage() external view returns (uint256);
}
