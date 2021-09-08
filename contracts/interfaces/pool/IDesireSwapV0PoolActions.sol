// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolActions 
{
    function swap(
        address to,
        bool zeroForOne,
        int256 amount,
        uint256 sqrtPriceLimit,
        bytes calldata data)
    external
	returns (int256, int256);

    function mint(
        address to,
        int24 lowestRangeIndex,
        int24 highestRangeIndex,
        uint256 liqToAdd,
		bytes calldata data)
    external
    returns(uint256 amount0, uint256 amount1);

    function burn(
        address to,
        uint256 ticketId)
	external
	returns (uint256, uint256);

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data)
    external;
}
