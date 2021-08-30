// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';

import"./Pool.sol";
import"./interfaces/IDesireSwapV0Factory.sol";

contract DesireSwapV0Factory is IUniswapV3Factory, IDesireSwapV0Factory {
    address public override(IUniswapV3Factory, IDesireSwapV0Factory) owner;
    address public override feeCollector;
    address public override body;

    bool public override protocolFeeIsOn;
    uint256 public override protocolFeePart;

    // struct poolTypeData{
    //     uint256 sqrtPositionMultiplier;
    //     uint256 fee;
    // }
    // poolTypeData[] poolType;
    // uint8 public poolTypeCount;
    // mapping(address => mapping(address => mapping(uint8 => address))) public poolAddress;
    mapping(address => mapping(address => mapping(uint24 => address))) public getPool;

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


    // function addPoolType(uint256 _sqrtPositionMultiplier, uint256 _fee) external override onlyBy(owner) {
    //     // require(feeToPoolTypeNumber[_fee] == 0);
    //     poolType[poolTypeCount] = poolTypeData({
    //         sqrtPositionMultiplier: _sqrtPositionMultiplier,
    //         fee: _fee
    //     });
    //     emit NewPoolType(poolTypeCount, _sqrtPositionMultiplier, _fee);
    //     poolTypeCount++;
    // }
  
    function createPool(address _tokenA, address _tokenB
        //, uint8 _poolTypeNumber, uint256 _startingSqrtBottomPrice
        , uint24 fee
    )
    external override onlyBy(owner) returns (address pool) {
        require(_tokenA != _tokenB);
        require(_tokenA != address(0) && _tokenB != address(0));
        (address token0, address token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(getPool[token0][token1][fee] == address(0));
        address pool = address(new DesireSwapV0Pool(address(this), token0, token1,
		    // poolType[_poolTypeNumber].sqrtPositionMultiplier, poolType[_poolTypeNumber].fee,
            // _startingSqrtBottomPrice));
            fee));
        getPool[token0][token1][fee] = pool;
        getPool[token1][token0][fee] = pool;
        emit PoolCreated(token0, token1, fee, pool);
    }

    function setOwner(address _owner) external override(IUniswapV3Factory, IDesireSwapV0Factory) onlyBy(owner) {
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

    // UV3Factory
    function feeAmountTickSpacing(uint24 fee) external override view returns (int24) {}

    // function getPool(
    //     address tokenA,
    //     address tokenB,
    //     uint24 fee
    // ) external override view returns (address pool) {
    //     require(fee == uint24(uint8(fee)));
    //     // uint8 = feeToPoolTypeNumber[fee];
    //     return poolAddress[tokenA][tokenB][uint8(0)];
    // }

    // function createPool(
    //     address tokenA,
    //     address tokenB,
    //     uint24 fee
    // ) external override returns (address pool) {}
    
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external override {}
}
