/// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './interfaces/IPoolDeployer.sol';
import './interfaces/IDesireSwapV0Factory.sol';

contract DesireSwapV0Factory is IDesireSwapV0Factory {
  // smallest sqrtRangeMultiplier
  uint256 private constant TICK_SIZE = 1000049998750062496;
  uint256 private constant E18 = 10**18;
  uint256 public override poolCount;
  address public override owner;
  address public override feeCollector;
  address public override swapRouter;
  address public immutable override deployerAddress;

  mapping(address => bool) public override allowlisted;

  mapping(address => mapping(address => mapping(uint256 => address))) public override poolAddress;

  mapping(uint256 => PoolType) public feeToPoolType;
  address[] public override poolList;

  constructor(address _owner, address deployerAddress_) {
    owner = _owner;
    feeCollector = _owner;
    deployerAddress = deployerAddress_;
    emit OwnerChanged(address(0), _owner);
    emit CollectorChanged(address(0), _owner);
    poolList.push(address(0));
    addPoolType(400, 1);
    addPoolType(500, 50);
    addPoolType(3000, 200);
  }

  modifier onlyByOwner() {
    require(msg.sender == owner, 'DesireSwapV0Factory: SENDER_IS_NOT_THE_OWNER');
    _;
  }

  /// inherit doc from IDesreSwapV0Factory
  function addPoolType(uint256 fee_, uint256 ticksInRange_) public override onlyByOwner {
    require(fee_ != 0 && ticksInRange_ != 0, 'FaPT0');
    require(feeToPoolType[fee_].ticksInRange == 0, 'FaPT1');
    feeToPoolType[fee_].ticksInRange = ticksInRange_;

    uint256 sqrtRangeMultiplier_ = E18;
    while (ticksInRange_ > 0) {
      sqrtRangeMultiplier_ = (sqrtRangeMultiplier_ * TICK_SIZE) / E18;
      ticksInRange_--;
    }
    uint256 sqrtRangeMultiplier100_ = E18;
    for(uint256 step = 0; step < 100; step++){
      sqrtRangeMultiplier100_ = sqrtRangeMultiplier100_ * sqrtRangeMultiplier_ /E18;
    }
    feeToPoolType[fee_].sqrtRangeMultiplier = sqrtRangeMultiplier_;
    feeToPoolType[fee_].sqrtRangeMultiplier100 = sqrtRangeMultiplier100_;
    emit NewPoolType(ticksInRange_, fee_);
  }


  /// inherit doc from IDesreSwapV0Factory
  function createPool(
    address tokenA_,
    address tokenB_,
    uint256 fee_,
    string memory name_,
    string memory symbol_
  ) external override onlyByOwner {
    require(tokenA_ != tokenB_, 'ARE_EQUAL');
    require(tokenA_ != address(0) && tokenB_ != address(0), '0ADDRESS');
    require(poolAddress[tokenA_][tokenB_][fee_] == address(0), 'ALREADY_EXISTS');
    require(feeToPoolType[fee_].ticksInRange > 0, 'POOLTYPE_UNDEFINED');
    address pool = IPoolDeployer(deployerAddress).deployPool(
      address(this),
      swapRouter,
      (tokenA_ < tokenB_ ? tokenA_ : tokenB_),
      (tokenB_ < tokenA_ ? tokenA_ : tokenB_),
      fee_, 
      feeToPoolType[fee_].ticksInRange,
      feeToPoolType[fee_].sqrtRangeMultiplier,
      feeToPoolType[fee_].sqrtRangeMultiplier100,
      name_,
      symbol_
    );
    poolAddress[tokenA_][tokenB_][fee_] = pool;
    poolAddress[tokenB_][tokenA_][fee_] = pool;
    poolList.push(pool);
    poolCount++;
    emit PoolCreated(tokenA_, tokenB_, fee_, pool);
  }

  function getPoolType(uint256 fee_)
  external view override
  returns (uint256 ticksInRange, uint256 sqrtRangeMultiplier, uint256 sqrtRangeMultiplier100){
    ticksInRange = feeToPoolType[fee_].ticksInRange;
    sqrtRangeMultiplier = feeToPoolType[fee_].sqrtRangeMultiplier;
    sqrtRangeMultiplier100 =  feeToPoolType[fee_].sqrtRangeMultiplier100;
  }

  /// inherit doc from IDesreSwapV0Factory
  function setOwner(address _owner) external override onlyByOwner {
    owner = _owner;
    emit OwnerChanged(owner, _owner);
  }

  /// inherit doc from IDesreSwapV0Factory
  function setFeeCollector(address _feeCollector) external override onlyByOwner {
    feeCollector = _feeCollector;
    emit CollectorChanged(feeCollector, _feeCollector);
  }

  /// inherit doc from IDesreSwapV0Factory
  function setSwapRouter(address swapRouter_) external override onlyByOwner {
    swapRouter = swapRouter_;
    emit SwapRouterChanged(swapRouter, swapRouter_);
  }
}
