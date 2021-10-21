// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import './callback/IDesireSwapV0MintCallback.sol';

interface ILiquidityManager is IDesireSwapV0MintCallback {
  event Supply(address indexed recipient, address indexed pool, uint256 ticketId);
  event Redeem(address indexed recipient, address indexed pool, uint256 ticketId);

  ///@notice makes transfer to the pool while supplying liquidity
  ///@param amount0Owed amount of token0 to transfer from supplier to pool
  ///@param amount1Owed amount of token1 to transfer from supplier to pool
  ///@param data NO IDEA YET
  function desireSwapV0MintCallback(
    uint256 amount0Owed,
    uint256 amount1Owed,
    bytes calldata data
  ) external override;

  struct SupplyParams {
    address token0;
    address token1;
    uint256 fee;
    int24 lowestRangeIndex;
    int24 highestRangeIndex;
    uint256 liqToAdd;
    uint256 amount0Max;
    uint256 amount1Max;
    address recipient;
    uint256 deadline;
  }

  /// @notice supplies the pool by calling mint method. 
  function supply(SupplyParams calldata params)
    external
    payable
    returns (
      address poolAddress,
      uint256 ticketId,
      uint256 amount0,
      uint256 amount1
    );
}
