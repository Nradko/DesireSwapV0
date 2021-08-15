// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./library/Ticket.sol";
import "./interfaces/IERC20.sol";
import './interfaces/IDesireSwapV0Factory.sol';
import './interfaces/IDesireSwapV0Pool.sol';

contract DesireSwapV0Pool is Ticket, IDesireSwapV0Pool
{
	bool public protocolFeeIsOn;

	address public immutable factory;
	address public immutable token0;
	address public immutable token1;

	uint256 public immutable sqrtPositionMultiplier;   // example: 100100000.... is 1.001 (* 10**36)
	uint256 public immutable feePercentage;            //  0 fee is 0 // 100% fee is 1* 10**36
	uint256 private protocolFeePercentage;
	uint256 private totalReserve0;
	uint256 private totalReserve1;
	uint256 private lastBalance0;
	uint256 private lastBalance1;

	int24 private inUsePosition;
	int24 private highestActivatedPosition;
	int24 private lowestActivatedPosition;

	struct Position {
		uint256 reserve0;
		uint256 reserve1;
		uint256 sqrtPriceBottom;    //  sqrt(lower position bound price) * 10**18 // price of token1 in token0 for 1 token0 i get priceBottom of tokens1
		uint256 sqrtPriceTop;
		uint256 supplyCoefficient; 	//
		bool activated;
	}
	mapping( int24 => Position) private positions;

	constructor (
		address _factory, address _token0, address _token1,
		uint256 _sqrtPositionMultiplier, uint256 _feePercentage,
		uint256 _startingSqrtPriceBottom
	){
		factory = _factory;
		token0 = _token0;
		token1 = _token1;
		sqrtPositionMultiplier = _sqrtPositionMultiplier;
		feePercentage = _feePercentage;

		positions[0].sqrtPriceBottom = _startingSqrtPriceBottom;
		positions[0].sqrtPriceTop = _startingSqrtPriceBottom*_sqrtPositionMultiplier/10**18;
		positions[0].activated = true;
	}

	function getLastBalances() external override view returns (uint256 _lastBalance0, uint256 _lastBalance1){
		_lastBalance0 = lastBalance0;
		_lastBalance1 = lastBalance1;
	}

	function getTotalReserves() external override view returns (uint256 _totalReserve0, uint256 _totalReserve1){
		_totalReserve0 = totalReserve0;
		_totalReserve1 = totalReserve1;
	}

	function getPositionInfo(int24 index) external override view
	returns (uint256 _reserve0, uint256 _reserve1, uint256 _sqrtPriceBottom, uint256 _sqrtPriceTop) {
		_reserve0 = positions[index].reserve0;
		_reserve1 = positions[index].reserve1;
		_sqrtPriceBottom = positions[index].sqrtPriceBottom;
		_sqrtPriceTop = positions[index].sqrtPriceTop;
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
        int24 lowestPositionIndex,
        int24 highestPositionIndex,
        uint256 positionValue)
        external override {
			address body = IDesireSwapV0Factory(factory).body(); 
			(bool success, bytes memory data) = body.delegatecall(
            	abi.encodeWithSignature("mint(address to, int24 lowestPositionIndex, int24 highestPositionIndex, uint256 positionValue)", to, lowestPositionIndex, highestPositionIndex, positionValue)
        );
		}

	function burn (address to, uint256 ticketID) external override{
		address body = IDesireSwapV0Factory(factory).body(); 
		(bool success, bytes memory data) = body.delegatecall(
        	abi.encodeWithSignature("burn(aaddress to, uint256 ticketID)", to, ticketID)
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


	bytes4 internal constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    function _safeTransfer( address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'DesireSwapV0: TRANSFER_FAILED');
    }

	function collectFee(address token, uint256 amount) external override{
		require(msg.sender == IDesireSwapV0Factory(factory).owner());
		_safeTransfer(token, IDesireSwapV0Factory(factory).feeCollector(), amount);
		require( IERC20(token0).balanceOf(address(this)) >= totalReserve0
			  && IERC20(token1).balanceOf(address(this)) >= totalReserve1);
		emit CollectFee(token, amount);
	}

	function setProtocolFee(bool turnOn, uint256 newFee) external override{
		require(msg.sender == IDesireSwapV0Factory(factory).owner());
		protocolFeeIsOn = turnOn;
		protocolFeePercentage = newFee;
	}
}
