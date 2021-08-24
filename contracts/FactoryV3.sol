// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';

import "./interfaces/IDesireSwapV0Factory.sol";

contract FactoryV3 is IUniswapV3Factory, IDesireSwapV0Factory {
    
    /*  EVENTS
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event PoolCreated(address indexed token0, address indexed token1, uint24 indexed fee, int24 tickSpacing, address pool);
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);
    */

    address public override(IUniswapV3Factory, IDesireSwapV0Factory) owner;
    
    // IDESIRESWAP
    address public override feeCollector;
    address public override body;
    bool public override protocolFeeIsOn;
    uint256 public override protocolFeePart;

    struct poolTypeData{
        uint256 sqrtPositionMultiplier;
        uint256 fee;
    }
    poolTypeData[] poolType;
    uint8 public poolTypeCount;
    mapping(uint256 => uint8) feeToPoolTypeNumber;
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

    function feeAmountTickSpacing(uint24 fee) external override view returns (int24) {

    }

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override view returns (address pool) {
        require(fee == uint24(uint8(fee)));
        return poolAddress[tokenA][tokenB][uint8(fee)];
    }

    // Incompatible signature
    function createPool(address _tokenA, address _tokenB, uint8 _poolType, uint256 _startingSqrtBottomPrice) external override {}
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override returns (address pool) {

    }
    
    function setOwner(address _owner) external override(IUniswapV3Factory, IDesireSwapV0Factory) onlyBy(owner) {
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    function enableFeeAmount(uint24 fee, int24 tickSpacing) external override {

    }

    // IDESIRESWAP FUNCS
    function setFeeCollector(address _feeCollector) external override {
        
    }
	function setBody(address _body) external override {
        
    }

    // analogic to UV3Factory `deploy` 
	function addPoolType(uint256 _sqrtPositionMultiplier, uint256 _fee) external override {

    }


}