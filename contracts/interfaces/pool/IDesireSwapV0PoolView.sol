// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolView {
  function inUseRange() external view returns (int24);

  function highestActivatedRange() external view returns (int24);

  function lowestActivatedRange() external view returns (int24);

  function initialized() external view returns (bool);

  function protocolFeeIsOn() external view returns (bool);

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
}
