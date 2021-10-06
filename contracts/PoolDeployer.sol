// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './Pool.sol';
import './interfaces/IPoolDeployer.sol';

contract PoolDeployer is IPoolDeployer {
  function deployPool(
    address factory_,
    address swapRouter_,
    address tokenA_,
    address tokenB_,
    uint256 fee_,
    uint256 ticksInRange_,
    string memory name_,
    string memory symbol_
  ) external override returns (address poolAddress) {
    poolAddress = address(new DesireSwapV0Pool(factory_, swapRouter_, tokenA_, tokenB_, fee_, ticksInRange_, name_, symbol_));
  }
}
