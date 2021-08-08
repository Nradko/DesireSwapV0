// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import"./Pool.sol";

contract Factory {
    address public owner;

    uint256[] public sqrtPositionMultiplier;
    uint256[] public fee;
    uint8 public poolTypeCount;
    mapping(address => mapping(address => mapping(uint8 => address))) public poolAddress;

    event NewPoolType(uint8 poolTypeNumber, uint256 positionMultiplier, uint256 fee);
    event PoolCreated(address token0, address token1, uint8 poolType, address pool);
    event OwnerChanged(address oldOwner, address newOwner);

    function addPoolType(uint256 _sqrtPositionMultiplier, uint256 _fee) public{
        require(msg.sender == owner);
        sqrtPositionMultiplier[poolTypeCount] = _sqrtPositionMultiplier;
        fee[poolTypeCount] = _fee;
        emit NewPoolType (poolTypeCount, _sqrtPositionMultiplier, _fee);
        poolTypeCount++;
    }
  
    constructor(){
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        poolTypeCount = 0;
        addPoolType(1.004987562*10**18, 0.3*10**18);
    }

    function createPool(address tokenA, address tokenB, uint8 poolType, uint256 startingSqrtBottomPrice)
    public{
        require(msg.sender == owner, "DesireFactory: You are not the owner of factory");
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0) && token1 != address(0));
        require(poolAddress[token0][token1][poolType] == address(0));
        address pool = address(new Pool(address(this), token0, token1,
		    sqrtPositionMultiplier[poolType], fee[poolType], startingSqrtBottomPrice));
        poolAddress[token0][token1][poolType] = pool;
        poolAddress[token1][token0][poolType] = pool;
        emit PoolCreated(token0, token1, poolType, pool);
    }

    function setOwner(address _owner) external {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }
}
