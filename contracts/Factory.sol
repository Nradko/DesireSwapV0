/// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './interfaces/IPoolDeployer.sol';
import './interfaces/IDesireSwapV0Factory.sol';

contract DesireSwapV0Factory is IDesireSwapV0Factory {
  address public override owner;
  address public override feeCollector;
  address public override swapRouter;
  address public immutable override deployerAddress;

  mapping(address => bool) public override whitelisted;

  mapping(uint256 => uint256) public override feeToTicksInRange;
  mapping(address => mapping(address => mapping(uint256 => address))) public override poolAddress;

  address[] public override poolList;
  uint256 public override poolCount = 0;

  modifier onlyBy(address _account) {
    require(msg.sender == owner, 'DesireSwapV0Factory: SENDER_IS_NOT_THE_OWNER');
    _;
  }

  constructor(address _owner, address deployerAddress_) {
    owner = _owner;
    feeCollector = _owner;
    emit OwnerChanged(address(0), _owner);
    poolList.push(address(0));
    feeToTicksInRange[4 * 10**14] = 1;
    feeToTicksInRange[5 * 10**14] = 10;
    feeToTicksInRange[3 * 10**15] = 50;
    feeToTicksInRange[10**16] = 200;
    deployerAddress = deployerAddress_;
  }

  function addPoolType(uint256 fee_, uint256 ticksInRange_) external override onlyBy(owner) {
    require(feeToTicksInRange[fee_] == 0);
    feeToTicksInRange[fee_] = ticksInRange_;
    emit NewPoolType(ticksInRange_, fee_);
  }

  function createPool(
    address tokenA_,
    address tokenB_,
    uint256 fee_,
    string memory name_,
    string memory symbol_
  ) external override onlyBy(owner) {
    require(tokenA_ != tokenB_, 'ARE_EQUAL');
    (address token0, address token1) = tokenA_ < tokenB_ ? (tokenA_, tokenB_) : (tokenB_, tokenA_);
    require(token0 != address(0) && token1 != address(0), '0ADDRESS');
    require(poolAddress[token0][token1][fee_] == address(0), 'ALREADY_EXISTS');
    address pool = IPoolDeployer(deployerAddress).deployPool(address(this), swapRouter, token0, token1, fee_, feeToTicksInRange[fee_], name_, symbol_);
    poolAddress[token0][token1][fee_] = pool;
    poolAddress[token1][token0][fee_] = pool;
    poolList.push(pool);
    poolCount++;
    emit PoolCreated(token0, token1, fee_, pool);
  }

  function setOwner(address _owner) external override onlyBy(owner) {
    emit OwnerChanged(owner, _owner);
    owner = _owner;
  }

  function setFeeCollector(address _feeCollector) external override onlyBy(owner) {
    emit CollectorChanged(feeCollector, _feeCollector);
    feeCollector = _feeCollector;
  }

  function setSwapRouter(address swapRouter_) external override onlyBy(owner) {
    emit SwapRouterChanged(swapRouter, swapRouter_);
    swapRouter = swapRouter_;
  }
}
