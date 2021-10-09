// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolView {
  function initialized() external view returns (bool);

  function protocolFeeIsOn() external view returns (bool);

  function swapRouter() external view returns (address);

  function protocolFeePart() external view returns (uint256);

  function inUseRange() external view returns (int24);

  function highestActivatedRange() external view returns (int24);

  function lowestActivatedRange() external view returns (int24);

  function balance0() external view returns (uint256);

  function balance1() external view returns (uint256);

  function getLastBalances() external view returns (uint256 _lastBalance0, uint256 _lastBalance1);

  function getTotalReserves() external view returns (uint256 _totalReserve0, uint256 _totalReserve1);

  function getRangeInfo(int24 index)
    external
    view
    returns (
      uint256 _reserve0,
      uint256 _reserve1,
      uint256 _sqrtPriceBottom,
      uint256 _sqrtPriceTop
    );

  function getFullRangeInfo(int24 index)
    external
    view
    returns (
      uint256 _reserve0,
      uint256 _reserve1,
      uint256 _sqrtPriceBottom,
      uint256 _sqrtPriceTop,
      uint256 _supplyCoefficient,
      bool _activated
    );

  function slot0()
    external
    view
    returns (
      int24 usingRange,
      uint256 reserve0,
      uint256 reserve1,
      uint256 liqInRange,
      uint256 currentPrice
    );
}
