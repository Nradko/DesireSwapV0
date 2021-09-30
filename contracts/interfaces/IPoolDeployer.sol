// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IPoolDeployer {
  function deployPool(
    address factory_,
    address swapRouter_,
    address tokenA_,
    address tokenB_,
    uint256 fee_,
    uint256 sqrtRangeMultiplier_,
    string memory name_,
    string memory symbol_
  ) external returns (address poolAddress);
}
