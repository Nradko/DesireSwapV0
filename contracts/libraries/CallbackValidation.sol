// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '../interfaces/IDesireSwapV0Pool.sol';
import '../interfaces/IDesireSwapV0Factory.sol';
import './PoolAddress.sol';

/// @notice Provides validation for callbacks from DesireSwap V0 Pools
library CallbackValidation {
  /// @notice Returns the address of a valid  DesireSwap V0 Pool
  /// @param factory The contract address of the  DesireSwap V0 factory
  /// @param tokenA The contract address of either token0 or token1
  /// @param tokenB The contract address of the other token
  /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
  /// @return pool The V3 pool contract address
  function verifyCallback(
    address factory,
    address tokenA,
    address tokenB,
    uint256 fee
  ) internal view returns (IDesireSwapV0Pool pool) {
    pool = IDesireSwapV0Pool(IDesireSwapV0Factory(factory).poolAddress(tokenA, tokenB, fee));
    require(msg.sender == address(pool));
  }

  function verifyCallback(address factory, PoolAddress.PoolKey memory poolKey) internal view returns (IDesireSwapV0Pool pool) {
    return verifyCallback(factory, poolKey.token0, poolKey.token1, poolKey.fee);
  }
}
