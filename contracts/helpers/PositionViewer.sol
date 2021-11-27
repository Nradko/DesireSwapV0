/************************************************************************************************
 * Copyright (C) 2021-2022  <desired.desire@protonmail.com>
 *
 * "Author" should be understood at person who is using email: <desired.desire@protonmail.com>
 *
 * This file is part of DesireSwap protocol and was developed by Author .
 *
 * DesireSwap protocol files that are said to be developed by Author can not be copied
 * and/or distributed without the express permission of Author.
 *
 * Author gives permission to everyone to copy and use these files only in order to test them.
 ************************************************************************************************/
pragma solidity ^0.8.0;

import '../interfaces/IDesireSwapV0Pool.sol';
import '../interfaces/pool/ITicket.sol';
import '../libraries/PoolHelper.sol';

import 'hardhat/console.sol';

contract PositionViewer {
  uint256 private constant E18 = 10**18;
  struct PositionData {
    address poolAddress;
    address token0;
    address token1;
    uint256 ticketId;
    int24 lowestTick;
    int24 highestTick;
    uint256 amount0;
    uint256 amount1;
    uint256 feeAmount;
    address owner;
  }

  function getCurrentSqrtPrice(address poolAddress) public view returns (uint256) {
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    (uint256 reserve0, uint256 reserve1, uint256 sqrt0, uint256 sqrt1, , ) = pool.getFullRangeInfo(pool.inUseRange());
    uint256 L = PoolHelper.liqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
    return ((L * E18) / (reserve1 + (L * sqrt0) / E18));
  }

  function _readTicket(
    address poolAddress,
    uint256 ticketId,
    int24 index
  ) private view returns (uint256 amount0, uint256 amount1) {
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    uint256 supply = pool.getTicketSupplyData(ticketId, index);
    (uint256 reserve0, uint256 reserve1, , , uint256 supplyCoefficient, ) = pool.getFullRangeInfo(index);
    require(supply > 0, 'supply jest rowny zero');
    require(supplyCoefficient > 0, 'supplyCoefficient jest rowny zero');
    amount0 = (supply * reserve0) / supplyCoefficient;
    amount1 = (supply * reserve1) / supplyCoefficient;
  }

  function getAmounts(address poolAddress, uint256 ticketId) private view returns (uint256 amount0, uint256 amount1) {
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    ITicket.TicketData memory ticketData = pool.getTicketData(ticketId);
    int24 lowestRangeIndex = ticketData.lowestRangeIndex;
    int24 highestRangeIndex = ticketData.highestRangeIndex;
    for (int24 i = lowestRangeIndex; i <= highestRangeIndex; i++) {
      (uint256 amount0ToAdd, uint256 amount1ToAdd) = _readTicket(poolAddress, ticketId, i);
      amount0 += amount0ToAdd;
      amount1 += amount1ToAdd;
    }
  }

  function getPositionData(address poolAddress, uint256 ticketId) public view returns (PositionData memory) {
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    (uint256 amount0, uint256 amount1) = getAmounts(poolAddress, ticketId);
    int24 ticksInRange = int24(uint24(pool.ticksInRange()));
    PositionData memory data = PositionData({
      poolAddress: poolAddress,
      token0: pool.token0(),
      token1: pool.token1(),
      ticketId: ticketId,
      lowestTick: pool.getTicketData(ticketId).lowestRangeIndex * ticksInRange,
      highestTick: (pool.getTicketData(ticketId).highestRangeIndex + 1) * ticksInRange,
      amount0: amount0,
      amount1: amount1,
      feeAmount: pool.fee(),
      owner: pool.ownerOf(ticketId)
    });
    return (data);
  }

  function getPositionDataList(address poolAddress, address owner) external view returns (PositionData[] memory positionDataList) {
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    uint256 ticketAmount = pool.getAddressTicketsAmount(owner);
    uint256 positionCount;
    for (uint256 i = 1; i < ticketAmount; i++) {
      uint256 ticketId = pool.getAddressTicketsByPosition(owner, i);
      if (ticketId != 0) positionCount++;
    }
    positionDataList = new PositionData[](positionCount);
    positionCount = 0;
    for (uint256 i = 1; i < ticketAmount; i++) {
      uint256 ticketId = pool.getAddressTicketsByPosition(owner, i);
      if (ticketId != 0) {
        positionDataList[positionCount] = getPositionData(poolAddress, ticketId);
        positionCount++;
      }
    }
    return (positionDataList);
  }

   function inUseInfo(address poolAddress)
    public
    view
    returns (
      int24 bottomActiveTick,
      uint256 sqrtCurrentPrice,
      uint256 inUseLiq,
      uint256 inUseReserve0,
      uint256 inUseReserve1
    )
  {
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    int24 inUseRange = pool.inUseRange();
    bottomActiveTick = inUseRange * int24(int256(pool.ticksInRange()));
    (uint256 reserve0, uint256 reserve1, uint256 sqrt0, uint256 sqrt1, ,) = pool.getFullRangeInfo(inUseRange);
    inUseLiq = PoolHelper.liqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
    sqrtCurrentPrice = (inUseLiq * E18) / (reserve0 + (inUseLiq * E18) / sqrt1);
    inUseReserve0 = reserve0;
    inUseReserve1 = reserve1;
  }

  struct GraphData{
    int24 bottomActiveTick;
    uint256 liquidity;
    uint256 price0;
  }
  
  function getGraphData(address poolAddress, int24 range)
  public
  view
  returns(GraphData memory)
  {
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    (uint256 reserve0, uint256 reserve1, uint256 sqrt0, uint256 sqrt1, ,) = pool.getFullRangeInfo(range);
    return GraphData({
      bottomActiveTick: range * int24(int256(pool.ticksInRange())),
      liquidity: PoolHelper.liqCoefficient(reserve0, reserve1, sqrt0, sqrt1),
      price0 : sqrt0*sqrt0/E18
    });
  }

  function graphData(address poolAddress)
  public
  view
  returns(GraphData[] memory graphDataList)
  {
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    int24 inUseRange = pool.inUseRange();
    graphDataList = new GraphData[](401);
    for (int i  = 0; i<= 400; i++){
      graphDataList[uint256(i)] = getGraphData(poolAddress, inUseRange - int24(200 + i));
    }
  }
}
