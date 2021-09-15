// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import"./Pool.sol";
import"./interfaces/IDesireSwapV0Factory.sol";

contract DesireSwapV0Factory is IDesireSwapV0Factory {
    address public override owner;
    address public override feeCollector;

    mapping(uint256 => uint256) public override feeToSqrtRangeMultiplier;
    mapping(address => mapping(address => mapping(uint256 => address))) public override poolAddress;

    address[] public override poolList;
    uint256 public override poolCount = 0;

    modifier onlyBy(address _account) {
        require(msg.sender == owner, "DesireSwapV0Factory: SENDER_IS_NOT_THE_OWNER");
        _;
    }

    constructor(address _owner){
        owner = _owner;
        feeCollector = _owner;
        emit OwnerChanged(address(0), _owner);
        poolList.push(address(0));
        feeToSqrtRangeMultiplier[5*10**14] = 1.000499875 * 10**18;
        feeToSqrtRangeMultiplier[3*10**15] = 1.002501875 * 10**18;
        feeToSqrtRangeMultiplier[10**16] = 1.01004512 * 10**18;
    }


    function addPoolType(uint256 _fee, uint256 _sqrtRangeMultiplier) external override onlyBy(owner) {
        require(feeToSqrtRangeMultiplier[_fee] == 0);
        feeToSqrtRangeMultiplier[_fee] = _sqrtRangeMultiplier ;
        emit NewPoolType (_sqrtRangeMultiplier, _fee);
    }
  
    function createPool(address _tokenA, address _tokenB,  uint256 _fee)
    external override onlyBy(owner) {
        require(_tokenA != _tokenB,'ARE_EQUAL');
        (address token0, address token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(token0 != address(0) && token1 != address(0),'0ADDRESS');
        require(poolAddress[token0][token1][_fee] == address(0),'ALREADY_EXISTS');
        address pool = address(new DesireSwapV0Pool(
            address(this), token0, token1,
		    _fee, feeToSqrtRangeMultiplier[_fee]
            ));
        poolAddress[token0][token1][_fee] = pool;
        poolAddress[token1][token0][_fee] = pool;
        poolList.push(pool);
        poolCount++;
        emit PoolCreated(token0, token1, _fee, pool);
    }

    function setOwner(address _owner) external override onlyBy(owner) {
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    function setFeeCollector(address _feeCollector) external override onlyBy(owner) {
        emit CollectorChanged(feeCollector, _feeCollector);
        feeCollector = _feeCollector;
    }

}
