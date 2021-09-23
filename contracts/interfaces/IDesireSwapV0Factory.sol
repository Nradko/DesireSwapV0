// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDesireSwapV0Factory {
  event NewPoolType(uint256 rangeMultiplier, uint256 fee);
  event PoolCreated(address token0, address token1, uint256 fee, address pool);
  event OwnerChanged(address oldOwner, address newOwner);
  event CollectorChanged(address oldFeeCollector, address newFeeCollector);
  event SwapRouterChanged(address odlSwapRouter, address newSwapRouter);

  function owner() external view returns (address);

  function feeCollector() external view returns (address);

  function swapRouter() external view returns (address);

  function deployerAddress() external view returns (address);

  function whitelisted(address) external view returns (bool);

  function feeToSqrtRangeMultiplier(uint256 fee) external view returns (uint256);

  function poolAddress(
    address,
    address,
    uint256
  ) external view returns (address);

  function poolList(uint256) external view returns (address);

  function poolCount() external view returns (uint256);

  function addPoolType(uint256 _fee, uint256 _sqrtRangeMultiplier) external;

  function createPool(
    address tokenA_,
    address tokenB_,
    uint256 fee_,
    string memory name_,
    string memory symbol_
  ) external;

  function setOwner(address _owner) external;

  function setFeeCollector(address _feeCollector) external;

  function setSwapRouter(address swapRouter_) external;
}
