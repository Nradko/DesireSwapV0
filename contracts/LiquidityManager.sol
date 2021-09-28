// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import './interfaces/IDesireSwapV0Factory.sol';
import './interfaces/IDesireSwapV0Pool.sol';

import './base/PeripheryPayments.sol';
import './base/PeripheryImmutableState.sol';

import './interfaces/ILiquidityManager.sol';

import './libraries/CallbackValidation.sol';
import 'hardhat/console.sol';

contract LiquidityManager is ILiquidityManager, PeripheryImmutableState, PeripheryPayments {
  constructor(address _factory, address _WETH9) PeripheryImmutableState(_factory, _WETH9) {}

  struct MintCallbackData {
    PoolAddress.PoolKey poolKey;
    address payer;
  }

  function desireSwapV0MintCallback(
    uint256 amount0Owed,
    uint256 amount1Owed,
    bytes calldata data
  ) external override {
    MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
    CallbackValidation.verifyCallback(factory, decoded.poolKey);
    require(decoded.payer == tx.origin);
    if (amount0Owed > 0) pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
    if (amount1Owed > 0) pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
  }

  function supply(SupplyParams calldata params)
    external
    payable
    override
    returns (
      address poolAddress,
      uint256 ticketId,
      uint256 amount0,
      uint256 amount1
    )
  {
    require(block.number < params.deadline, 'DSV0LM(redeem): deadline');
    require(params.liqToAdd > 0, 'DSV0LM(supply): liquidity=0');
    PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(params.token0, params.token1, params.fee);
    poolAddress = PoolAddress.computeAddress(factory, poolKey);
    require(poolAddress != address(0), 'DSV0LM(supply): pool=0');
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    (ticketId, amount0, amount1) = pool.mint(params.recipient, params.lowestRangeIndex, params.highestRangeIndex, params.liqToAdd, abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender})));
    require(amount0 <= params.amount0Max && amount1 <= params.amount1Max, 'DSV0LM(supply): amountMax_exceeded');
    ticketId = pool.getNextTicketId() - 1;
    emit Supply(params.recipient, poolAddress, ticketId);
  }
}
