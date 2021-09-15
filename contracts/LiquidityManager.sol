// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import './coreInterfaces/IDesireSwapV0Factory.sol';
import './coreInterfaces/IDesireSwapV0Pool.sol';

import './base/PeripheryPayments.sol';
import './base/PeripheryImmutableState.sol';

import './interfaces/ILiquidityManager.sol';

import './libraries/CallbackValidation.sol';
import 'hardhat/console.sol';

contract LiquidityManager is ILiquidityManager, PeripheryImmutableState, PeripheryPayments {
  // details about the desireswap position
  struct Position {
    // the address that is approved for spending this token
    address owner;
    // address of pool that was supplied
    address pool;
    // ticketId connected to this supply position
    uint256 ticketId;
  }

  /// @dev The token ID position data
  mapping(uint256 => Position) private _positions;

  uint256 private nextPositionId = 1;

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
    console.log('mintCallback_start');
    MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
    CallbackValidation.verifyCallback(factory, decoded.poolKey);
    require(decoded.payer == tx.origin);
    if (amount0Owed > 0) pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
    if (amount1Owed > 0) pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
  }

  function positions(uint256 positionId)
    external
    view
    override
    returns (
      address owner,
      address pool,
      uint256 ticketId
    )
  {
    Position memory position = _positions[positionId];
    require(position.pool != address(0), 'Invalid token ID');
    return (position.owner, position.pool, position.ticketId);
  }

  function addPosition(
    address owner,
    address pool,
    uint256 ticketId
  ) private returns (uint256) {
    _positions[nextPositionId] = Position({owner: owner, pool: pool, ticketId: ticketId});
    return nextPositionId++;
  }

  function supplyParams(
    address token0,
    address token1,
    uint256 fee,
    int24 lowestRangeIndex,
    int24 highestRangeIndex,
    uint256 liqToAdd,
    uint256 amount0Max,
    uint256 amount1Max,
    address recipient,
    uint256 deadline
  ) external returns (SupplyParams memory params) {
    params = SupplyParams({
      token0: token0,
      token1: token1,
      fee: fee,
      lowestRangeIndex: lowestRangeIndex,
      highestRangeIndex: highestRangeIndex,
      liqToAdd: liqToAdd,
      amount0Max: amount0Max,
      amount1Max: amount1Max,
      recipient: recipient,
      deadline: deadline
    });
  }

  function supply(SupplyParams calldata params)
    external
    payable
    override
    returns (
      uint256 positionId,
      uint256 ticketId,
      uint256 amount0,
      uint256 amount1,
      address poolAddress
    )
  {
    require(block.timestamp < params.deadline, 'DSV0LM(redeem): deadline');
    require(params.liqToAdd > 0, 'DSV0LM(supply): liquidity=0');
    PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(params.token0, params.token1, params.fee);
    poolAddress = PoolAddress.computeAddress(factory, poolKey);
    require(poolAddress != address(0), 'DSV0LM(supply): pool=0');
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    (amount0, amount1) = pool.mint(params.recipient, params.lowestRangeIndex, params.highestRangeIndex, params.liqToAdd, abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender})));
    require(amount0 <= params.amount0Max && amount1 <= params.amount1Max, 'DSV0LM(supply): amountMax_exceeded');
    ticketId = pool.getNextId() - 1;
    positionId = addPosition(params.recipient, poolAddress, ticketId);
    emit Supply(params.recipient, positionId, poolAddress, ticketId);
  }

  function redeem(RedeemParams calldata params) external payable override returns (uint256 amount0, uint256 amount1) {
    require(block.timestamp < params.deadline, 'DSV0LM(redeem): deadline');
    Position memory position = _positions[params.positionId];
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(position.pool);
    (amount0, amount1) = pool.burn(position.owner, position.ticketId);
    emit Redeem(params.recipient, params.positionId, position.pool, position.ticketId);
  }
}
