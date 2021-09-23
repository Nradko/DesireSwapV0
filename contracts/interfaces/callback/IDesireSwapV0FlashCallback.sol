// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDesireSwapV0FlashCallback {
  function desireSwapV0FlashCallback(
    uint256 fee0,
    uint256 fee1,
    bytes calldata data
  ) external;
}
