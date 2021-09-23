// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolOwnerActions {
  function initialize(int24 _startingInUseRange) external;

  function collectFee(address token, uint256 amount) external;

  function setProtocolFee(bool _protocolFeeIsOn, uint256 _protocolFeePart) external;

  function setSwapRouter() external;
}
