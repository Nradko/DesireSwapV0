// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import"./Pool.sol";
import"./interfaces/IDesireSwapV0Factory.sol";

contract DesireSwapV0Factory is IDesireSwapV0Factory {
    address public override owner;
    address public override feeCollector;
    address public override body;

    bool public override protocolFeeIsOn;
    uint256 public override protocolFeePart;

    uint256[] public sqrtPositionMultiplier;
    uint256[] public fee;
    uint8 public poolTypeCount;
    mapping(address => mapping(address => mapping(uint8 => address))) public poolAddress;

    modifier onlyBy(address _account) {
        require(msg.sender == owner, "DesireSwapV0Factory: SENDER_IS_NOT_THE_OWNER");
        _;
    }

    constructor(address _body){
        owner = msg.sender;
        feeCollector = msg.sender;
        emit OwnerChanged(address(0), msg.sender);
        body = _body;
        emit BodyChanged(address(0), body);
    }


    function addPoolType(uint256 _sqrtPositionMultiplier, uint256 _fee) external override onlyBy(owner) {
        sqrtPositionMultiplier[poolTypeCount] = _sqrtPositionMultiplier;
        fee[poolTypeCount] = _fee;
        emit NewPoolType (poolTypeCount, _sqrtPositionMultiplier, _fee);
        poolTypeCount++;
    }
  
    function createPool(address _tokenA, address _tokenB, uint8 _poolType, uint256 _startingSqrtBottomPrice)
    external override onlyBy(owner) {
        require(_tokenA != _tokenB);
        (address token0, address token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(token0 != address(0) && token1 != address(0));
        require(poolAddress[token0][token1][_poolType] == address(0));
        address pool = address(new DesireSwapV0Pool(address(this), token0, token1,
		    sqrtPositionMultiplier[_poolType], fee[_poolType], _startingSqrtBottomPrice));
        poolAddress[token0][token1][_poolType] = pool;
        poolAddress[token1][token0][_poolType] = pool;
        emit PoolCreated(token0, token1, _poolType, pool);
    }

    function setOwner(address _owner) external override onlyBy(owner) {
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    function setFeeCollector(address _feeCollector) external override onlyBy(owner) {
        emit CollectorChanged(feeCollector, _feeCollector);
        feeCollector = _feeCollector;
    }

    function setBody(address _body) external override onlyBy(owner) {
        emit BodyChanged(body, _body);
        body = _body;
    }
}
