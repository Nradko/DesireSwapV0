// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDesireSwapV0Pool {
	event SwapInRange(address msgSender, int24 index, bool zeroForOne, uint256 amountIn, uint256 amountOut, address to);
	event RangeActivated(int24 index);
	event InUseRangeChanged(int24 index);
	event Swap(address msgSender, bool zeroForOne, int256 amount, address to);
	event Mint(address indexed to, uint256 ticketID, int24 lowestRangeIndex, int24 highestRangeIndex, uint256 positionValue, uint256 amount0, uint256 amount1);
	event Burn(address indexed owner, uint256 ticketID, int24 lowestRangeIndex, int24 highestRangeIndex, uint256 positionValue, uint256 amount0Transfered, uint256 amount1Transfered);
	event CollectFee(address token, uint256 amount);

	function getLastBalances() 
	external view
	returns (uint256 _lastBalance0, uint256 _lastBalance1);
	
	function getTotalReserves()
	external view 
	returns (uint256 _totalReserve0, uint256 _totalReserve1);

	function getRangeInfo(int24 index)
	external view
	returns (uint256 _reserve0, uint256 _reserve1, uint256 _sqrtPriceBottom, uint256 _sqrtPriceTop);

	function swap(
        address to,
        bool zeroForOne,
        int256 amount,
        uint256 sqrtPriceLimit,
        bytes calldata data
    )
	external
	returns (int256 amount0, int256 amount1);

	function mint(
        address to,
        int24 lowestRangeIndex,
        int24 highestRangeIndex,
        uint256 positionValue,
		bytes calldata data
		)
    external
	returns (uint256 amount0, uint256 amount1);

	function burn(
		address to,
		uint256 ticketID
		)
	external
	returns (uint256 amount0, uint256 amount1);

	function flash(
	address to,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

	function collectFee(address token, uint256 amount) external;	
}
