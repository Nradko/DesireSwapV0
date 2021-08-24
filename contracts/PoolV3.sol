// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

contract PoolV3 is IUniswapV3Pool {

    // IMMUTABLES
    function factory() external override view returns (address) {

    }

    function token0() external override view returns (address) {

    }

    function token1() external override view returns (address) {

    }

    function fee() external override view returns (uint24) {

    }

    function tickSpacing() external override view returns (int24) {

    }

    function maxLiquidityPerTick() external override view returns (uint128) {

    }


    // POOL STATE
    function slot0()
        external override
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        ) {

    }

    function feeGrowthGlobal0X128() external override view returns (uint256) {

    }

    function feeGrowthGlobal1X128() external override view returns (uint256) {

    }

    function protocolFees() external override view returns (uint128 token0, uint128 token1) {

    }

    function liquidity() external override view returns (uint128) {

    }

    function ticks(int24 tick)
        external override
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        ) {

    }

    function tickBitmap(int16 wordPosition) external override view returns (uint256) {

    }

    function positions(bytes32 key)
        external override
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) {

    }

    function observations(uint256 index)
        external override
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        ) {

    }


    // ACTIONS
    function initialize(uint160 sqrtPriceX96) external override {

    }

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external override returns (uint256 amount0, uint256 amount1) {

    }

    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override returns (uint128 amount0, uint128 amount1) {

    }

    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external override returns (uint256 amount0, uint256 amount1) {

    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {

    }

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {

    }

    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external override {

    }


    // OWNER ACTIONS
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external override {

    }

    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override returns (uint128 amount0, uint128 amount1) {

    }


    // DERIVED STATE
    function observe(
        uint32[] calldata secondsAgos
    ) external override view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) {

    }

    function snapshotCumulativesInside(
        int24 tickLower, int24 tickUpper
    ) external override view returns (
        int56 tickCumulativeInside,
        uint160 secondsPerLiquidityInsideX128,
        uint32 secondsInside
    ) {

    }

    /*  EVENTS
    event Initialize(uint160 sqrtPriceX96, int24 tick);
    event Mint(address sender, address indexed owner, int24 indexed tickLower, int24 indexed tickUpper, uint128 amount, uint256 amount0, uint256 amount1);
    event Collect(address indexed owner, address recipient, int24 indexed tickLower, int24 indexed tickUpper, uint128 amount0, uint128 amount1);
    event Burn(address indexed owner, int24 indexed tickLower, int24 indexed tickUpper, uint128 amount, uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, address indexed recipient, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick);
    event Flash(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1, uint256 paid0, uint256 paid1);
    event IncreaseObservationCardinalityNext(uint16 observationCardinalityNextOld, uint16 observationCardinalityNextNew);
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);
    */
}