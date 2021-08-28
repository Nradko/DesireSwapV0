// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Ticket.sol";
import "./library/TransferHelper.sol";
import "./interfaces/IERC20.sol";
import './interfaces/IDesireSwapV0Factory.sol';
import './interfaces/IDesireSwapV0Pool.sol';

contract DesireSwapV0Pool is Ticket, IDesireSwapV0Pool {
	address public immutable factory;
	address public immutable token0;
	address public immutable token1;

	uint256 public immutable sqrtRangeMultiplier;   // example: 100100000.... is 1.001 (* 10**36)
	uint256 public immutable feePercentage;            //  0 fee is 0 // 100% fee is 1* 10**36;
	uint256 private totalReserve0;
	uint256 private totalReserve1;
	uint256 private lastBalance0;
	uint256 private lastBalance1;

	int24 private inUseRange;
	int24 private highestActivatedRange;
	int24 private lowestActivatedRange;

	struct Range {
		uint256 reserve0;
		uint256 reserve1;
		uint256 sqrtPriceBottom;    //  sqrt(lower position bound price) * 10**18 // price of token1 in token0 for 1 token0 i get priceBottom of tokens1
		uint256 sqrtPriceTop;
		uint256 supplyCoefficient; 	//
		bool activated;
	}
	mapping(int24 => Range) private ranges;

	constructor(
		address _factory, address _token0, address _token1,
		uint256 _sqrtRangeMultiplier, uint256 _feePercentage,
		uint256 _startingSqrtPriceBottom
	){
		factory = _factory;
		token0 = _token0;
		token1 = _token1;
		sqrtRangeMultiplier = _sqrtRangeMultiplier;
		feePercentage = _feePercentage;

		ranges[0].sqrtPriceBottom = _startingSqrtPriceBottom;
		ranges[0].sqrtPriceTop = _startingSqrtPriceBottom*_sqrtRangeMultiplier/10**18;
		ranges[0].activated = true;
	}

	function getLastBalances() external override view returns (uint256 _lastBalance0, uint256 _lastBalance1) {
		_lastBalance0 = lastBalance0;
		_lastBalance1 = lastBalance1;
	}

	function getTotalReserves() external override view returns (uint256 _totalReserve0, uint256 _totalReserve1) {
		_totalReserve0 = totalReserve0;
		_totalReserve1 = totalReserve1;
	}

	function getRangeInfo(int24 index) external override view
	returns (uint256 _reserve0, uint256 _reserve1, uint256 _sqrtPriceBottom, uint256 _sqrtPriceTop) {
		_reserve0 = ranges[index].reserve0;
		_reserve1 = ranges[index].reserve1;
		_sqrtPriceBottom = ranges[index].sqrtPriceBottom;
		_sqrtPriceTop = ranges[index].sqrtPriceTop;
	}

	function swap(
        address to,
        bool zeroForOne,
        int256 amount,
        uint256 sqrtPriceLimit,
        bytes calldata data
    ) external override returns(int256 amount0, int256 amount1) {
		address body = IDesireSwapV0Factory(factory).body(); 
		(bool success, bytes memory data) = body.delegatecall(
            abi.encodeWithSignature("swap(address to, bool zeroForOne, int256 amount, uint256 sqrtPriceLimit,bytes calldata data)"
			, to, zeroForOne, amount, sqrtPriceLimit, data)
        );
	}

	function mint(
        address to,
        int24 lowestRangeIndex,
        int24 highestRangeIndex,
        uint256 positionValue)
        external override {
			address body = IDesireSwapV0Factory(factory).body(); 
			(bool success, bytes memory data) = body.delegatecall(
            	abi.encodeWithSignature("mint(address to, int24 lowestRangeIndex, int24 highestRangeIndex, uint256 positionValue)", to, lowestRangeIndex, highestRangeIndex, positionValue)
        );
	}

	function burn(address to, uint256 ticketID) external override {
		address body = IDesireSwapV0Factory(factory).body(); 
		(bool success, bytes memory data) = body.delegatecall(
        	abi.encodeWithSignature("burn(address to, uint256 ticketID)", to, ticketID)
        );
	}

	function flash(
	address to,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override{
		address body = IDesireSwapV0Factory(factory).body(); 
		(bool success, bytes memory data) = body.delegatecall(
        	abi.encodeWithSignature("flash(address to, uint256 amount0, uint256 amount1, bytes calldata data)",to, amount0, amount1, data)
        );
	}

	function collectFee(address token, uint256 amount) external override {
		require(msg.sender == IDesireSwapV0Factory(factory).owner());
		TransferHelper.safeTransfer(token, IDesireSwapV0Factory(factory).feeCollector(), amount);
		require( IERC20(token0).balanceOf(address(this)) >= totalReserve0
			  && IERC20(token1).balanceOf(address(this)) >= totalReserve1);
		emit CollectFee(token, amount);
	}
}
