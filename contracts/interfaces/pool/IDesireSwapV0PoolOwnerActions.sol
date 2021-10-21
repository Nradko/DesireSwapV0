// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolOwnerActions {

  /// note initialize 1st range and calculates its sqrtPrice boundaries
  /// @param _startingInUseRange index of range to be initialized
  function initialize(int24 _startingInUseRange) external;

  /// note collects protocolFee
  /// @param token address of token of which fee should be ollected
  /// @param amount amount of fee that should be collected
  function collectFee(address token, uint256 amount) external;

  /// note sets protocol fee part of swap fee and turns it on/off
  /// @param _protocolFeeIsOn true set protocol fee on, false to set protocol fee off
  /// @param _protocolFeePart protocol fee part of swap fee in percentage 100% = 10**18
  function setProtocolFee(bool _protocolFeeIsOn, uint256 _protocolFeePart) external;

  /// note sets swapRouter to the one defined in factory
  function setSwapRouter() external;
}
