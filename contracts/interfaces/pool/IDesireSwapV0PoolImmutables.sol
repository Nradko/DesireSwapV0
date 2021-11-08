// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolImmutables {
  
  /// @return return address of factory
  function factory() external view returns (address);

/// @return return address of token0
  function token0() external view returns (address);

/// @return return address of token1
  function token1() external view returns (address);

/// @return return ticks in ranges
  function ticksInRange() external view returns (uint256);

/// @return sqrtRangeMultiplier which describes price ranges of pools
  function sqrtRangeMultiplier() external view returns (uint256);

/// @return feePercentage of the pool. 100% = 10**18;
  function fee() external view returns (uint256);
}
