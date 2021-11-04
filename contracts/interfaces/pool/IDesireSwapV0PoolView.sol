// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolView {
  /// return the global variables ///
  function initialized() external view returns (bool);

  function protocolFeeIsOn() external view returns (bool);

  function swapRouter() external view returns (address);

  function protocolFeePart() external view returns (uint256);

  function inUseRange() external view returns (int24);

  function highestActivatedRange() external view returns (int24);

  function lowestActivatedRange() external view returns (int24);

  /// @return returns balance of token0 in pool
  function balance0() external view returns (uint256);

  /// @return returns balance of token1 in pool
  function balance1() external view returns (uint256);

  /// @return _lastBalance0  and _lastBalance1 return last balances, it is balances after last swap,burn,mint, or flash
  function getLastBalances() external view returns (uint256 _lastBalance0, uint256 _lastBalance1);

  /// @return _totalReserve0 and _totalReserve1, amount of token0 and token1 in pool that is not the collected fee
  function getTotalReserves() external view returns (uint256 _totalReserve0, uint256 _totalReserve1);

  /// note returns data of range with index = index
  /// @param index of range which data is returned
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

  /// note returns importand for interface data of range inUse.
  function inUseInfo()
    external
    view
    returns (
      int24 usingRange,
      uint256 sqrtCurrentPrice,
      uint256 inUseLiq,
      uint256 inUseReserve0,
      uint256 inUseReserve1
    );
}
