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
    PositionData memory data = PositionData({
      poolAddress: poolAddress,
      token0: pool.token0(),
      token1: pool.token1(),
      ticketId: ticketId,
      lowestTick: pool.getTicketData(ticketId).lowestRangeIndex,
      highestTick: pool.getTicketData(ticketId).highestRangeIndex,
      amount0: amount0,
      amount1: amount1,
      feeAmount: pool.fee(),
      owner: pool.getTicketData(ticketId).owner
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

  function getTicketOwner(address poolAddress, uint256 ticketId) public view returns (address) {
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    return pool.getTicketOwner(ticketId);
  }
}
