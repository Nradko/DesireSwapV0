// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IPoolDeployer {
  
  /// note deploys the DesireSwapV0Pool
  /// @param factory_ address of factory
  /// @param swapRouter_ address of swapRouter
  /// @param tokenA_ address of token0
  /// @param tokenB_ address of token1
  /// @param fee_ swap fee of the pool
  /// @param ticksInRange_ defines size of Pool
  /// @param sqrtRangeMultiplier_ size of Pool
  /// @param sqrtRangeMultiplier100_ (sizeOfPool)**100
  /// @param name_ name of pool
  /// @param symbol_ symbol of pool
  function deployPool(
    address factory_,
    address swapRouter_,
    address tokenA_,
    address tokenB_,
    uint256 fee_,
    uint256 ticksInRange_,
    uint256 sqrtRangeMultiplier_,
    uint256 sqrtRangeMultiplier100_,
    string memory name_,
    string memory symbol_
  ) external returns (address poolAddress);
}
