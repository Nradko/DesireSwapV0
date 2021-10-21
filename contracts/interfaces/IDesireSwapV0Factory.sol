// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IDesireSwapV0Factory {
  event NewPoolType(uint256 rangeMultiplier, uint256 fee);
  event PoolCreated(address token0, address token1, uint256 fee, address pool);
  event OwnerChanged(address oldOwner, address newOwner);
  event CollectorChanged(address oldFeeCollector, address newFeeCollector);
  event SwapRouterChanged(address odlSwapRouter, address newSwapRouter);

  /// @return the addres of rhe owner of factory
  function owner() external view returns (address);

  /// @return the feeCollector contract address. Fees are colleected from pools to this contract
  function feeCollector() external view returns (address);

  /// @return swapRouter contract address.
  function swapRouter() external view returns (address);

  /// @return the deployers contract address
  function deployerAddress() external view returns (address);

  /// @notice allowlisted is a map (address => bool) storing infromation if a given address is allowlisted to interact with swap router
  /// @param () to be checked if is allowlisted to interact with swap router(not importanf for external addresses)
  /// @return true if contract can interact with swapRouter
  function allowlisted(address) external view returns (bool);

  /// @notice map ticks in a range corresponding to the fee
  /// @param () fee of the pool
  /// @return ticks in a single range
  function feeToTicksInRange(uint256 fee) external view returns (uint256);

  /// @param () 1st ERC20 token in pool
  /// @param () 2nd ERC20 token in pool
  /// @param () fee of the pool
  /// @return adress of the pool
  function poolAddress(
    address,
    address,
    uint256
  ) external view returns (address);

  /// @notice list of all the created pools in order of creation
  function poolList(uint256) external view returns (address);

  /// @return number of existing pools
  function poolCount() external view returns (uint256);

  /// @notice creates new pool type with _fee and _sqrtRangeMultiplier
  function addPoolType(uint256 fee_, uint256 sqrtRangeMultiplier_) external;

  /// @notice deploys a new pool with given parameters. If one with same tokenA_, tokenB_, fee_ haven't been created yet
  function createPool(
    address tokenA_,
    address tokenB_,
    uint256 fee_,
    string memory name_,
    string memory symbol_
  ) external;

  /// onwer action, setting global variables
  function setOwner(address _owner) external;

  function setFeeCollector(address _feeCollector) external;

  function setSwapRouter(address swapRouter_) external;
}
