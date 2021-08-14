// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./library/PoolHelper.sol";
import "./library/interfaces/IERC20.sol";
import "./library/Ticket.sol";
import './library/interfaces/IDesireSwapV0Factory.sol';

contract DesireSwapV0PoolBody is Ticket, PoolHelper
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

	event SwapInPosition(address msgSender, int24 index, bool zeroForOne, uint256 amountIn, uint256 amountOut, address to);
	event PositionActivated(int24 index);
	event InUsePositionChanged(int24 index);
	event Swap( address msgSender, bool zeroForOne, int256 amount, address to);
	event Mint(address to, uint256 ticketID, int24 lowestPositionIndex, int24 highestPositionIndex, uint256 positionValue, uint256 amount0, uint256 amount1);
	event Burn(address owner, uint256 ticketID, int24 lowestPositionIndex, int24 highestPositionIndex, uint256 positionValue, uint256 amount0Transfered, uint256 amount1Transfered);
	event CollectFee(address token, uint256 amount);



	bytes4 internal constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    function _safeTransfer( address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'DesireSwapV0: TRANSFER_FAILED');
    }
///
/// VIEW FUNCTIONS
///

	function getPositionInfo(int24 index) public view
	returns (uint256 _reserve0, uint256 _reserve1, uint256 _sqrtPriceBottom, uint256 _sqrtPriceTop) {
		_reserve0 = positions[index].reserve0;
		_reserve1 = positions[index].reserve1;
		_sqrtPriceBottom = positions[index].sqrtPriceBottom;
		_sqrtPriceTop = positions[index].sqrtPriceTop;
	}

///
/// Modify LastBalances, positions.reserves and TotalReserves functions
///
	function _updateLastBalances(uint256 _lastBalance0, uint256 _lastBalance1) private {
		lastBalance0 = _lastBalance0;
		lastBalance1 = _lastBalance1;
	}

	function _modifyPositionReserves(
		int24 index,
		uint256 toAdd0, uint256 toAdd1,
		bool add0, bool add1)
		private
	{
		positions[index].reserve0 = add0 ? positions[index].reserve0 + toAdd0 : positions[index].reserve0 - toAdd0;
		positions[index].reserve1 = add1 ? positions[index].reserve1 +toAdd1 : positions[index].reserve1 - toAdd1;
		totalReserve0 = add0 ? totalReserve0 + toAdd0: totalReserve0 -toAdd0;
		totalReserve1 = add1 ? totalReserve1 + toAdd0: totalReserve1 -toAdd1;
        if (positions[index].reserve0 == 0 && positions[index-1].activated == true){
            inUsePosition--;
            emit InUsePositionChanged(index-1);
        }
		if(positions[index].reserve1 == 0 && positions[index+1].activated == true){
            inUsePosition++;
            emit InUsePositionChanged(index+1);
        }
	}
///
/// Position activation
///
	function activate(int24 index) private{
		require(positions[index].activated == false, 'DesireSwapV0: THIS_POSITION_WAS_ALREADY_ACTIVATED');
		if( index > highestActivatedPosition ){
			highestActivatedPosition = index;
			if (positions[index-1].activated == false) activate(index-1);
			positions[index].sqrtPriceBottom = positions[index-1].sqrtPriceTop;
			positions[index].sqrtPriceTop = positions[index].sqrtPriceBottom*sqrtPositionMultiplier/10**18;
			positions[index].activated = true;
		}
		else if(index < lowestActivatedPosition){
			lowestActivatedPosition = index;
			if(positions[index+1].activated == false) activate(index +1);
			positions[index].sqrtPriceTop = positions[index+1].sqrtPriceBottom;
			positions[index].sqrtPriceBottom = positions[index].sqrtPriceTop*10**18/sqrtPositionMultiplier;
			positions[index].activated = true;
		}
		emit PositionActivated(index);
	}

///
/// Swapping
///

	// below function make swap inside only one position. It is used to make "whole" swap.
	// it swaps token0 to token1 if zeroForOne, else it swaps token1 to token 0.
	// it swaps tokensForExactTokens only.
	// amountOut is amount transfered to address "to"
	// !! IT TRANSFERS TOKENS OUT OF POOL !!
	// !! IT MODIFIES IMPORTANT DATA !!

	struct helpData{
        uint256 lastBalance0;
		uint256 lastBalance1;
		uint256 balance0;
		uint256 balance1;
        uint256 value00;
        uint256 value01;
        uint256 value10;
        uint256 value11;
    }
	function _swapInPosition(
        int24 index,
        address to,
        bool zeroForOne,
        uint256 amountOut) private returns( uint256 amountIn)
    {
        require(index == inUsePosition, 'DesireSwapV0: WRONG_INDEX');
		helpData memory h = helpData({
			lastBalance0:lastBalance0, lastBalance1:lastBalance1,
			balance0:0, balance1:0,
			value00: positions[index].reserve0, value01: positions[index].reserve1,
			value10: positions[index].sqrtPriceBottom, value11: positions[index].sqrtPriceTop
			});
        require( ( zeroForOne == true && amountOut <= h.value01) ||
                 ( zeroForOne == false && amountOut <= h.value00), 'DesireSwapV0: INSUFFICIENT_POSITION_LIQUIDITY');        
		
		uint256 L = LiqCoefficient(h.value00, h.value01, h.value10, h.value11);
        uint256 collectedFee;
		uint256 amountInHelp = _amountIn(zeroForOne, h.value00, h.value01, h.value10, h.value11, amountOut, L); // do not include fees;
        uint256 collectedProtocolFee = 0;

        amountIn = amountInHelp*10**36/(10**36 - feePercentage);
        collectedFee = amountIn - amountInHelp;
        if (protocolFeeIsOn)
            collectedProtocolFee = (collectedFee * protocolFeePercentage)/10**36;
        // token0 for token1 // token0 in; token1 out;
        if( zeroForOne) {
            //??
            require(LiqCoefficient(h.value00 + amountInHelp, h.value01 - amountOut, h.value10, h.value11) >= L,
             'DesireSwapV0: LIQ_COEFFICIENT_IS_TO_LOW'); //assure that after swap there is more or equal liquidity. If _amountIn works correctly it can be removed.
            //!!
            _modifyPositionReserves(
                index,
                amountIn - collectedProtocolFee,
                amountOut, true, false);
        }
        // token1 for token0 // token1 in; token0 out;
        if( zeroForOne == false) {    
            //??
            require(LiqCoefficient(h.value00 - amountOut, h.value01 + amountInHelp, h.value00, h.value11) >= L,
            'DesireSwapV0: LIQ_COEFFICIENT_IS_TO_LOW'); //assure that after swao there is more or equal liquidity. If _amountIn works correctly it can be removed.            
            //!!
            _modifyPositionReserves(
                index,
                amountOut,
                amountIn - collectedProtocolFee, false, true);
        }
        emit SwapInPosition(msg.sender, index, zeroForOne, amountIn, amountOut, to);
		delete h;
    }


	// This function uses swapInPosition to make any swap.
    // The calldata is not yet used. SwapRoutes!!!!!!!
    // amount > 0 amount is exact token inflow, amount < 0 amount is exact token outflow.
    // sqrtPriceLimit is price

	function swap(
        address to,
        bool zeroForOne,
        int256 amount //,
        //uint256 sqrtPriceLimit,
        //bytes calldata data
    ) external returns (int256, int256)
    {        
        helpData memory h = helpData({
			lastBalance0: lastBalance0, lastBalance1:lastBalance1,
			balance0: 0, balance1: 0,
			value00: 0, value01: 0,
			value10: 0, value11: 0});
		uint256 usingReserve;
        uint256 amountRecieved;
		uint256 remained;
        int24 usingPosition = inUsePosition;
        
        //
        // tokensForExactTokens
        //
        // token0 In, token1 Out, tokensForExactTokens
        if(amount <= 0){
            remained = uint256(-amount);
            if( zeroForOne){
                require(remained <= totalReserve1);
                ///!!! token transfer
                _safeTransfer(token1, to, remained);
                usingReserve = positions[usingPosition].reserve1;        
            }
            // token1 In, token0 Out, tokensForExactTokens
            else{
                require(remained <= totalReserve0);
                ///!!! token transfer
                _safeTransfer(token0, to, remained);
                usingReserve = positions[usingPosition].reserve0;        
                //???
            }
                while( remained > usingReserve) {
                    amountRecieved += _swapInPosition( usingPosition, to, zeroForOne, usingReserve);
                    remained -= usingReserve;
                    usingPosition = inUsePosition;
                    usingReserve = zeroForOne ? positions[usingPosition].reserve1 : positions[usingPosition].reserve0;
                }
                amountRecieved +=_swapInPosition( usingPosition, to, zeroForOne, remained);
                h.balance0 = IERC20(token0).balanceOf(address(this));
                h.balance1 = IERC20(token1).balanceOf(address(this));
            if( zeroForOne){
                require( h.balance0 >= h.lastBalance0 + amountRecieved && h.balance1 >= h.lastBalance1 - uint256(-amount),
                        'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');
            } else {
                require( h.balance1 >= h.lastBalance1 + amountRecieved && h.balance0 >= h.lastBalance0 - uint256(-amount),
                        'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');
            }

            
        } 
        //
        //  exactTokensForTokens
        //
        // token0 In, token1 Out, exactTokensForTokens
        else{
            remained = uint256(amount);
            uint256 predictedFee = remained *feePercentage/10**18;
            (h.value00, h.value01, h.value10, h.value11) = getPositionInfo(usingPosition); 
            uint256 L = LiqCoefficient( h.value00, h.value01, h.value10, h.value11);
            uint256 amountSend =0;
            uint256 amountOut = _amountOut(zeroForOne, h.value00, h.value01, h.value10, h.value11, remained-predictedFee, L);
            while( amountOut >= (zeroForOne? h.value01 : h.value00)) {
                remained -= _swapInPosition(usingPosition, to, zeroForOne, h.value00);
                usingPosition = inUsePosition;
                amountSend += zeroForOne ? h.value01 : h.value00;
                predictedFee = remained *feePercentage/10**18;
                (h.value00, h.value01, h.value10, h.value11) = getPositionInfo(usingPosition); 
                L = LiqCoefficient( h.value00, h.value01, h.value10, h.value11);
                amountOut = _amountOut(zeroForOne, h.value00, h.value01, h.value10, h.value11, remained-predictedFee, L);
            }
            remained -= _swapInPosition(usingPosition, to, zeroForOne, amountOut);
            amountSend +=amountOut;

            //!!!
                _safeTransfer(zeroForOne ? token1: token0, to, amountSend);
                h.balance0 = IERC20(token0).balanceOf(address(this));
                h.balance1 = IERC20(token1).balanceOf(address(this));
            if( zeroForOne){
                //???
                require( h.balance0 >= h.lastBalance0 + uint256(amount) && h.balance1 >= h.lastBalance1 - amountSend,
                        'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');            
            }
            else{
                //???
                require( h.balance0 >= h.lastBalance0 - amountSend  && h.balance1 >= h.lastBalance1 + uint256(amount),
                        'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');
            }
        }
        int256 amount0 = int256(h.balance0) - int256(h.lastBalance0);
		int256 amount1 = int256(h.balance1) - int256(h.lastBalance1);
		_updateLastBalances(h.balance0, h.balance1);
        emit Swap( msg.sender, zeroForOne, amount, to);
		delete h;
		return (amount0, amount1);
    }
///
///	ADD LIQUIDITY
///

	//  The proof of being LP is Ticket that stores information of how much liquidity was provided.
	//  It is minted when L is provided.
	//  It is burned when L is taken.

	function _printOnTicket0(int24 index, uint256 ticketID, uint256 positionValue) private{ 
		if (positions[index].activated == false) activate(index);    
		if(positions[index].supplyCoefficient != 0){
			_ticketSupplyData[ticketID][index] = positions[index].supplyCoefficient*positionValue/positions[index].reserve0;
		}
		else{
			_ticketSupplyData[ticketID][index] = positionValue;
		}
		positions[index].supplyCoefficient += _ticketSupplyData[ticketID][index];
		//!!
		_modifyPositionReserves(index, positionValue, 0, true, true); 
	}
	function _printOnTicket1(int24 index, uint256 ticketID, uint256 positionValue)
	private returns(uint256 amount1ToAdd){ 
		if(positions[index].activated == false) activate(index);
		amount1ToAdd = positionValue /sqrtPositionMultiplier**2/10**36;
		if(positions[index].supplyCoefficient != 0){
			_ticketSupplyData[ticketID][index] = positions[index].supplyCoefficient*amount1ToAdd/positions[index].reserve1;
		}
		else{
			_ticketSupplyData[ticketID][index] = positionValue;
		}
		positions[index].supplyCoefficient += _ticketSupplyData[ticketID][index];
		//!!
		_modifyPositionReserves(index, 0, amount1ToAdd, true, true); 
	}
		
	function mint(
        address to,
        int24 lowestPositionIndex,
        int24 highestPositionIndex,
        uint256 positionValue)
        external
        returns(uint256 amount0 , uint256 amount1)
    {
        require(highestPositionIndex >= lowestPositionIndex);
		helpData memory h = helpData({
			lastBalance0: lastBalance0, lastBalance1: lastBalance1,
			balance0: 0, balance1: 0,
			value00: 0, value01: 0,
			value10: 0, value11: 0});
        h.balance0 = IERC20(token0).balanceOf(address(this));
        h.balance1 = IERC20(token1).balanceOf(address(this));
		uint256 ticketID = _mint(to);
        int24 usingPosition = inUsePosition;   
		_ticketData[ticketID].lowestPositionIndex = lowestPositionIndex;
		_ticketData[ticketID].highestPositionIndex = highestPositionIndex;
		_ticketData[ticketID].positionValue = positionValue;

        if(highestPositionIndex < usingPosition){
			//in this case positions.reserve1 should be 0
            amount0 = (uint256(int256(highestPositionIndex - lowestPositionIndex)) + 1) * positionValue;
            for(int24 i = highestPositionIndex; i >= lowestPositionIndex; i--){
                _printOnTicket0(i, ticketID, positionValue);                
            }
        }
		else if(lowestPositionIndex > usingPosition)
        {
            // in this case positions.reserve0 should be 0
            for(int24 i = lowestPositionIndex; i <= highestPositionIndex; i++){
                amount1 +=  _printOnTicket1(i, ticketID, positionValue);
            }
            
        }else
        {
            amount0 = uint256(int256(highestPositionIndex - inUsePosition)) * positionValue;

            for(int24 i = usingPosition - 1; i >= lowestPositionIndex; i--){
                _printOnTicket0(i, ticketID, positionValue);               
            }
			
			for(int24 i = usingPosition + 1; i >= highestPositionIndex; i++){
				amount1 +=  _printOnTicket1(i, ticketID, positionValue); 
            }


            if(positions[usingPosition].activated == false) activate(usingPosition);
            (h.value00, h.value01, h.value10, h.value11) = getPositionInfo(usingPosition); 
            uint256 amount0ToAdd = h.balance0 - lastBalance0 - amount0;
            uint256 amount1ToAdd = h.balance1 - lastBalance1 - amount1;
			uint256 price0 = _currentPrice(h.value00, h.value01, h.value10, h.value11);
			uint256 price1 = _currentPrice(h.value00 +amount0ToAdd, h.value01 + amount1ToAdd, h.value10, h.value11);
			
			require(amount0ToAdd + amount1ToAdd*price0/10**18 >= positionValue); // twn warunek trzeba sprawdzic czy jest wystarczajacy lub czy nie jest za silny!!!!
			require(amount0ToAdd + amount1ToAdd*price1/10**18 >= positionValue);
			amount0 += amount0ToAdd;
			amount1 += amount1ToAdd;

            if(positions[usingPosition].supplyCoefficient != 0){
				_ticketSupplyData[ticketID][usingPosition] = positions[usingPosition].supplyCoefficient * (amount0ToAdd + amount1ToAdd*price1/10**18)/(h.value00 + h.value01*price1/10**18);             
            } else 
            {
                _ticketSupplyData[ticketID][usingPosition] = positionValue;                
            }
            //!!
			positions[usingPosition].supplyCoefficient += _ticketSupplyData[ticketID][usingPosition];
			//!!
            _modifyPositionReserves(usingPosition, amount0ToAdd, amount1ToAdd, true ,true); 
        }
		///???
		require(h.balance0 >= h.lastBalance0 + amount0 && h.balance1 >= h.lastBalance1 + amount1, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
	    emit Mint(to, ticketID, lowestPositionIndex, highestPositionIndex, positionValue, amount0, amount1);
        _updateLastBalances(h.balance0, h.balance1);
    }

///
///	REDEEM LIQ
///
	// zeroOrOne 0=false if only token0 in reserves, 1=true if only token 1 in reserves.
	function _readTicket(int24 index, uint256 ticketID, bool zeroOrOne)
	private returns(uint256 amountToTransfer){
		uint256 supply = _ticketSupplyData[ticketID][index];
		if(zeroOrOne){
			amountToTransfer = supply*positions[index].reserve0/positions[index].supplyCoefficient;
			//!!
			_modifyPositionReserves(index, amountToTransfer, 0, false, false);
		} else {
			amountToTransfer = supply*positions[index].reserve1/positions[index].supplyCoefficient;
			//!!
			_modifyPositionReserves(index, 0, amountToTransfer, false, false);			
		}
		//!!
		positions[index].supplyCoefficient -= supply;
	}

	function burn (address to, uint256 ticketID) external{
		require( _exists(ticketID), 'DesireSwapV0: THE_ERC721_DO_NOT_EXISTS');
		address owner = Ticket.ownerOf(ticketID);
		require( tx.origin == owner,'DesireSwapV0: THE_TX.ORIGIN_IS_NOT_THE_OWNER');
		_burn(ticketID);

		helpData memory h;
		h.lastBalance0 = lastBalance0;
		h.lastBalance1 = lastBalance1;
		int24 usingPosition = inUsePosition;
			
		int24 highestPositionIndex = _ticketData[ticketID].highestPositionIndex;
		int24 lowestPositionIndex = _ticketData[ticketID].lowestPositionIndex;
		if(highestPositionIndex < usingPosition){
			for(int24 i = highestPositionIndex; i >= highestPositionIndex; i--){
				h.value00 += _readTicket(i, ticketID, false);
			}
		} else if(lowestPositionIndex > usingPosition){
			for(int24 i = lowestPositionIndex; i <= highestPositionIndex; i++){
				h.value01 += _readTicket(i, ticketID, true);
			}
		} else
		{
			for(int24 i = highestPositionIndex; i > usingPosition; i--){
				h.value00 += _readTicket(i, ticketID, false);
			}
			for(int24 i = lowestPositionIndex; i < usingPosition; i++){
				h.value01 += _readTicket(i, ticketID, true);
			}
				
			uint256 supply = _ticketSupplyData[ticketID][usingPosition];
			h.value10 = supply*positions[usingPosition].reserve0/positions[usingPosition].supplyCoefficient;
			h.value11 = supply*positions[usingPosition].reserve1/positions[usingPosition].supplyCoefficient;
			h.value00 += h.value10;
			h.value01 += h.value11;
			_modifyPositionReserves(usingPosition, h.value10, h.value11, false, false);
			positions[usingPosition].supplyCoefficient -= supply;
		}
		//!!!
		_safeTransfer(token0, to, h.value00);
		_safeTransfer(token1, to, h.value01);
		h.balance0 = IERC20(token0).balanceOf(address(this));
		h.balance1 = IERC20(token1).balanceOf(address(this));
		//???
		require(h.balance0 >= h.lastBalance0 - h.value00 && h.balance1 >= h.lastBalance1 - h.value01, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
		emit Burn(owner, ticketID, lowestPositionIndex, highestPositionIndex, _ticketData[ticketID].positionValue, h.value00, h.value01);
		//!!!
		_updateLastBalances(h.balance0, h.balance1);
	}

	///
	/// Factory Owner Actions
	///

	function collectFee(address token, uint256 amount) external{
		require(msg.sender == IDesireSwapV0Factory(factory).owner());
		_safeTransfer(token, IDesireSwapV0Factory(factory).feeCollector(), amount);
		require( IERC20(token0).balanceOf(address(this)) >= totalReserve0
			  && IERC20(token1).balanceOf(address(this)) >= totalReserve1);
		emit CollectFee(token, amount);
	}

	function setProtocolFee(bool turnOn, uint256 newFee) external{
		require(msg.sender == IDesireSwapV0Factory(factory).owner());
		protocolFeeIsOn = turnOn;
		protocolFeePercentage = newFee;
	}

}