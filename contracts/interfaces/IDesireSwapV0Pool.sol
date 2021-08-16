// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDesireSwapV0Pool
{
	event SwapInPosition(address msgSender, int24 index, bool zeroForOne, uint256 amountIn, uint256 amountOut, address to);
	event PositionActivated(int24 index);
	event InUsePositionChanged(int24 index);
	event Swap( address msgSender, bool zeroForOne, int256 amount, address to);
	event Mint(address to, uint256 ticketID, int24 lowestPositionIndex, int24 highestPositionIndex, uint256 positionValue, uint256 amount0, uint256 amount1);
	event Burn(address owner, uint256 ticketID, int24 lowestPositionIndex, int24 highestPositionIndex, uint256 positionValue, uint256 amount0Transfered, uint256 amount1Transfered);
	event CollectFee(address token, uint256 amount);

	function getLastBalances() external view returns (uint256 _lastBalance0, uint256 _lastBalance1);
	function getTotalReserves() external view returns (uint256 _totalReserve0, uint256 _totalReserve1);

	function getPositionInfo(int24 index) external view
	returns (uint256 _reserve0, uint256 _reserve1, uint256 _sqrtPriceBottom, uint256 _sqrtPriceTop);

	function swap(
        address to,
        bool zeroForOne,
        int256 amount,
        uint256 sqrtPriceLimit,
        bytes calldata data
    ) external returns(int256 amount0, int256 amount1);

	function mint(
        address to,
        int24 lowestPositionIndex,
        int24 highestPositionIndex,
        uint256 positionValue)
        external;

	function burn (address to, uint256 ticketID) external;

	function flash(
	address to,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

// FactoryOwnerActions.
	function collectFee(address token, uint256 amount) external;	
}
