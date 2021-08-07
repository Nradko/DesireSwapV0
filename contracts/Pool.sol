// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./PoolHelper.sol";
import "./library/IERC20.sol";
import "./Ticket.sol";

abstract contract Pool is PoolHelper, IERC20, Ticket
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
	uint256 private collectedProtocolFee0; // moze mozna usunac
	uint256 private collectedProtocolFee1;
	uint256 private blockTimestampLast;

	int24 private inUsePosition;
	int24 private highestActivatedPosition;
	int24 private lowestActivatedPosition;

	struct Position {
		uint256 reserve0;
		uint256 reserve1;
		uint256 sqrtPriceBottom;    //  sqrt(lower position bound price) * 10**18 // price of token1 in token0.
		uint256 sqrtPriceTop;
		uint256 supplyCoefficient; 	//
		bool activated;
	}
	mapping( int24 => Position) private positions;

	constructor (address _factory, address _token0, address _token1, uint256 _sqrtPositionMultiplier, uint256 _feePercentage){
		factory = _factory;
		token0 = _token0;
		token1 = _token1;
		sqrtPositionMultiplier = _sqrtPositionMultiplier;
		feePercentage = _feePercentage;
	}

	event SwapInPosition(address msgSender, int24 index, bool zeroForOne, uint256 amountIn, uint256 amountOut, address to);
	event PositionActivated(int24 index);
	event InUsePositionChanged(int24 index);
	event Swap( address msgSender, bool zeroForOne, int256 amount, address to);
	event Mint(address to, uint256 ticketID, int24 lowestPositionIndex, int24 highestPositionIndex, uint256 positionValue, uint256 amount0, uint256 amount1);
///
/// VIEW FUNCTIONS
///

	function getLastBalances() public view
	returns (uint256 _lastBalance0, uint256 _lastBalance1) {
		_lastBalance0 = lastBalance0;
		_lastBalance1 = lastBalance1;
	}

	function getTotalReserves() public view
	returns (uint _totalReserve0, uint256 _totalReserve1){
		_totalReserve0 = totalReserve0;
		_totalReserve1 = totalReserve1;
	}

	function getPositionReserves(int24 index) public view
	returns (uint256 _reserve0, uint256 _reserve1) {
		_reserve0 = positions[index].reserve0;
		_reserve1 = positions[index].reserve1;
	}

	function getPositionSqrtPrices(int24 index) public view
	returns (uint256 _sqrtPriceBottom, uint256 _sqrtPriceTop){
		_sqrtPriceBottom = positions[index].sqrtPriceBottom;
		_sqrtPriceTop = positions[index].sqrtPriceTop;
	}

	function getProtocolFeePercentage() public view
	returns(uint256 _protocolFeePercentage)
	{
		_protocolFeePercentage = protocolFeePercentage;
	}

///
/// Modify LastBalances, positions.reserves and TotalReserves functions
///
	function _updateLastBalances(uint256 _lastBalance0, uint256 _lastBalance1) private {
		lastBalance0 = _lastBalance0;
		lastBalance1 = _lastBalance1;
		blockTimestampLast = block.timestamp;
	}

	function _addAddPositionReserves(
		int24 index,
		uint256 toAdd0, uint256 toAdd1)
		internal
	{
		positions[index].reserve0 += toAdd0;
		positions[index].reserve1 += toAdd1;
		totalReserve0 += toAdd0;
		totalReserve1 += toAdd1;
	}

	function _subAddPositionReserves (
		int24 index,
		uint256 toSub0, uint256 toAdd1)
		internal
	{
		positions[index].reserve0 -= toSub0;
		positions[index].reserve1 += toAdd1;
		totalReserve0 -= toSub0;
		totalReserve1 += toAdd1;
	}

	function _addSubPositionReserves (
		int24 index,
		uint256 toAdd0, uint256 toSub1)
		internal
	{
		positions[index].reserve0 += toAdd0;
		positions[index].reserve1 -= toSub1;
		totalReserve0 += toAdd0;
		totalReserve1 -= toSub1;
	}

	function _subSubPositionReserves (
		int24 index,
		uint256 toSub0, uint256 toSub1)
		internal
	{
		positions[index].reserve0 -= toSub0;
		positions[index].reserve1 -= toSub1;
		totalReserve0 -= toSub0;
		totalReserve1 -= toSub1;
	}

///
/// Position activation
///
	function activate(int24 index) private{
		require(positions[index].activated == false, 'DesireSwapV0: THIS_POSITION_WAS_ALREADY_ACTIVATED');
		Position memory positionToActivate;
		positionToActivate.reserve0 = 0;
		positionToActivate.reserve1 = 0;
		positionToActivate.supplyCoefficient = 0;
		if( index > highestActivatedPosition ){
		highestActivatedPosition = index;
		if (positions[index-1].activated == false) activate(index-1);
		positionToActivate.sqrtPriceBottom = positions[index-1].sqrtPriceTop;
		positionToActivate.sqrtPriceTop = positionToActivate.sqrtPriceBottom*sqrtPositionMultiplier/10**18;
		positionToActivate.activated = true;
		}
		else if(index < lowestActivatedPosition){
		lowestActivatedPosition = index;
		if(positions[index+1].activated == false) activate(index +1);
		positionToActivate.sqrtPriceTop = positions[index+1].sqrtPriceBottom;
		positionToActivate.sqrtPriceBottom = positionToActivate.sqrtPriceTop*10**18/sqrtPositionMultiplier;
		positionToActivate.activated = true;
		}
		positions[index] = positionToActivate;
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

	function _swapInPosition(
        int24 index,
        address to,
        bool zeroForOne,
        uint256 amountOut) private returns( uint256 amountIn)
    {
        require(index == inUsePosition, 'DesireSwapV0: WRONG_INDEX');
        (uint256 reserve0, uint256 reserve1) = getPositionReserves(index);
        (uint256 _lastBalance0, uint256 _lastBalance1) = getLastBalances();
        (uint256 sqrtBottom, uint256 sqrtTop) = getPositionSqrtPrices(index);
        uint256 L = LiqCoefficient(reserve0, reserve1, sqrtBottom, sqrtTop);
        uint256 collectedFee;
        address _token0 = token0;
        address _token1 = token1;

        require( ( zeroForOne == true && amountOut <= reserve1) ||
                 ( zeroForOne == false && amountOut <= reserve0), 'DesireSwapV0: INSUFFICIENT_POSITION_LIQUIDITY');

        // token0 for token1 // token0 in; token1 out;
        if( zeroForOne) {
            // !!!
            _safeTransfer(_token1, to, amountOut);
            uint256 amountInHelp = _amountIn(zeroForOne, reserve0, reserve1, sqrtBottom, sqrtTop, amountOut, L); // do not include fees;
            uint256 collectedProtocolFee = 0;
            amountIn = amountInHelp*10**36/(10**36 - feePercentage);
            collectedFee = amountIn - amountInHelp;
            if (protocolFeeIsOn){
                collectedProtocolFee = (collectedFee * protocolFeePercentage)/10**36;
                //!!
                collectedProtocolFee0 += collectedProtocolFee;
            }

            //??
            require(LiqCoefficient(reserve0 + amountIn - collectedFee, reserve1 - amountOut, sqrtBottom, sqrtTop) >= L,
             'DesireSwapV0: LIQ_COEFFICIENT_IS_TO_LOW'); //assure that after swap there is more or equal liquidity. If _amountIn works correctly it can be removed.

            //!!
            _addSubPositionReserves(
                index,
                amountIn - collectedProtocolFee,
                amountOut);

            reserve1 = positions[index].reserve1;
            if( reserve1 == 0){
                inUsePosition--; // to powiina robic funckja
                emit InUsePositionChanged(index+1);
            }

            uint256 balance0 = IERC20(token0).balanceOf(address(this));
            uint256 balance1 = IERC20(token1).balanceOf(address(this));            
            //???
            require(balance0 >= _lastBalance0 + amountIn && balance1 >= _lastBalance1 - amountOut, 'DesireSwapV0: TO_LOW_BALANCES');
            //!!!
            _updateLastBalances(
                _lastBalance0 + amountIn,
                _lastBalance1 - amountOut);

        }
        // token1 for token0 // token1 in; token0 out;
        if( zeroForOne == false) {
            //!!!
            _safeTransfer(_token0, to, amountOut);
            uint256 amountInHelp = _amountIn(zeroForOne, reserve0, reserve1, sqrtBottom, sqrtTop, amountOut, L); // do not include fees;
            uint256 collectedProtocolFee = 0;
            amountIn = amountInHelp*10**36/(10**36 - feePercentage);
            collectedFee = amountIn - amountInHelp;

            if (protocolFeeIsOn){
                collectedProtocolFee = (collectedFee * protocolFeePercentage)/10**36;
                //!!
                collectedProtocolFee1 += collectedProtocolFee;
            }
            
            //??
            require(LiqCoefficient(reserve0 - amountOut, reserve1 + amountIn - collectedFee, sqrtBottom, sqrtTop) >= L,
            'DesireSwapV0: LIQ_COEFFICIENT_IS_TO_LOW'); //assure that after swao there is more or equal liquidity. If _amountIn works correctly it can be removed.
            
            //!!
            _subAddPositionReserves(
                index,
                amountOut,
                amountIn - collectedProtocolFee);

            reserve0 = positions[index].reserve0;
            //??
            if( reserve0 == 0){
                inUsePosition++;   // to powinna robic funkcja
                emit InUsePositionChanged(index-1);
            }

            uint256 balance0 = IERC20(token0).balanceOf(address(this));
            uint256 balance1 = IERC20(token1).balanceOf(address(this));   
            //??
            require(balance0 >= _lastBalance0 -amountOut && balance1 >= _lastBalance1 + amountIn, 'DesireSwapV0: TO_LOW_BALANCES');
            //!!
            _updateLastBalances(
                _lastBalance0 - amountOut,
                _lastBalance1 + amountIn);
        }
        emit SwapInPosition(msg.sender, index, zeroForOne, amountIn, amountOut, to);
    }


	// This function uses swapInPosition to make any swap.
    // The calldata is not yet used. SwapRoutes!!!!!!!
    // amount > 0 amount is exact token inflow, amount < 0 amount is exact token outflow.
    // sqrtPriceLimit is price
    function swap(
        address to,
        bool zeroForOne,
        int256 amount,
        uint256 sqrtPriceLimit,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1)
    {        
        (uint256 _lastBalance0, uint256 _lastBalance1) = getLastBalances();
        uint256 amountRecieved =0;
        int24 usingPosition = inUsePosition;
        
        //
        // tokensForExactTokens
        //
        // token0 In, token1 Out, tokensForExactTokens
        if( zeroForOne && amount < 0 && uint256(-amount) <= totalReserve1){
            uint256 remained = uint256(-amount);
            uint256 usingReserve = positions[usingPosition].reserve1;        
            while( remained > usingReserve) {
                amountRecieved += _swapInPosition( usingPosition, to, true, usingReserve);
                remained -= usingReserve;
                usingPosition = inUsePosition;
                usingReserve = positions[usingPosition].reserve1;
            }
            amountRecieved +=_swapInPosition( usingPosition, to, true, remained);
            uint256 balance0 = IERC20(token0).balanceOf(address(this));
            uint256 balance1 = IERC20(token1).balanceOf(address(this));
            //??? Aditional safety check!
            require( balance0 >= _lastBalance0 + amountRecieved && balance1 >= _lastBalance1 - uint256(-amount),
                    'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');
			amount0 = int256(balance0) - int256(_lastBalance0);
			amount1 = int256(balance1) - int256(_lastBalance1);
			_updateLastBalances(
                balance0,
                balance1);
            emit Swap( msg.sender, zeroForOne, amount, to);
        }

        // token1 In, token0 Out, tokensForExactTokens
        if( zeroForOne == false && amount < 0 && uint256(-amount) <= lastBalance0){
            uint256 remained = uint256(-amount);
            uint256 usingReserve = positions[usingPosition].reserve0;        
            while( remained > usingReserve) {
                amountRecieved += _swapInPosition( usingPosition, to, false, usingReserve);
                remained -= usingReserve;
                usingPosition = inUsePosition;
                usingReserve = positions[usingPosition].reserve0;
            }
            amountRecieved +=_swapInPosition( usingPosition, to, false, remained);
            uint256 balance0 = IERC20(token0).balanceOf(address(this));
            uint256 balance1 = IERC20(token1).balanceOf(address(this));
            //??? Aditional safety check!
            require( balance1 >= _lastBalance1 + amountRecieved && balance0 >= _lastBalance0 - uint256(-amount),
                    'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');
			amount0 = int256(balance0) - int256(_lastBalance0);
			amount1 = int256(balance1) - int256(_lastBalance1);
            //!!
			_updateLastBalances(
                balance0,
                balance1);
            emit Swap( msg.sender, zeroForOne, amount, to);
        } 


        //
        //  exactTokensForTokens
        //
        // token0 In, token1 Out, exactTokensForTokens
        if( zeroForOne && amount > 0){
            uint256 remained = uint256(amount);
            uint256 predictedFee = remained *feePercentage/10**18;
            (uint256 reserve0, uint256 reserve1) = getPositionReserves(usingPosition); 
            (uint256 sqrtBottom, uint256 sqrtTop) = getPositionSqrtPrices(usingPosition); 
            uint256 L = LiqCoefficient( reserve0, reserve1, sqrtBottom, sqrtTop);
            uint256 amountSend =0;
            uint256 amountOut = _amountOut(zeroForOne, reserve0, reserve1, sqrtBottom, sqrtTop, remained-predictedFee, L);
            while( amountOut >= reserve1) {
                remained -= _swapInPosition(usingPosition, to, zeroForOne, reserve1);
                usingPosition++;
                amountSend +=reserve1;
                predictedFee = remained *feePercentage/10**18;
                (reserve0, reserve1) = getPositionReserves(usingPosition);
                (sqrtBottom, sqrtTop) = getPositionSqrtPrices(usingPosition);
                L = LiqCoefficient( reserve0, reserve1, sqrtBottom, sqrtTop);
                amountOut = _amountOut(zeroForOne, reserve0, reserve1, sqrtBottom, sqrtTop, remained-predictedFee, L);
            }
            remained -= _swapInPosition(usingPosition, to, zeroForOne, amountOut);
            amountSend +=amountOut;

            uint256 balance0 = IERC20(token0).balanceOf(address(this));
            uint256 balance1 = IERC20(token1).balanceOf(address(this));
            //?? Aditional safety check!
            require( balance0 >= _lastBalance0 + uint256(amount) && balance1 >= _lastBalance1 - amountSend,
                    'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');
            
			amount0 = int256(balance0) - int256(_lastBalance0);
			amount1 = int256(balance1) - int256(_lastBalance1);
			//!!
			_updateLastBalances(
                balance0,
                balance1);
            emit Swap( msg.sender, zeroForOne, amount, to);
        }
        
        // token1 In, token0 Out, exactTokensForTokens
        if( zeroForOne == false && amount > 0){
            uint256 remained = uint256(amount);
            uint256 predictedFee = remained *feePercentage/10**18;
            (uint256 reserve0, uint256 reserve1) = getPositionReserves(usingPosition); 
            (uint256 sqrtBottom, uint256 sqrtTop) = getPositionSqrtPrices(usingPosition);
            uint256 L = LiqCoefficient( reserve0, reserve1, sqrtBottom, sqrtTop);
            uint256 amountSend =0;
            uint256 amountOut = _amountOut(zeroForOne, reserve0, reserve1, sqrtBottom, sqrtTop, remained-predictedFee, L);
            while( amountOut >= reserve0) {
                remained -= _swapInPosition(usingPosition, to, zeroForOne, reserve0);
                usingPosition++;
                amountSend += reserve0;
                predictedFee = remained *feePercentage/10**18;
                (reserve0, reserve1) = getPositionReserves(usingPosition);
                (sqrtBottom, sqrtTop) = getPositionSqrtPrices(usingPosition);
                L = LiqCoefficient( reserve0, reserve1, sqrtBottom, sqrtTop);
                amountOut = _amountOut(zeroForOne, reserve0, reserve1, sqrtBottom, sqrtTop, remained-predictedFee, L);
            }
            remained -= _swapInPosition(usingPosition, to, zeroForOne, amountOut);
            amountSend +=amountOut;

            uint256 balance0 = IERC20(token0).balanceOf(address(this));
            uint256 balance1 = IERC20(token1).balanceOf(address(this));
            //?? Aditional safety check!
            require( balance0 >= _lastBalance0 - amountSend  && balance1 >= _lastBalance1 + uint256(amount),
                    'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');

			amount0 = int256(balance0) - int256(_lastBalance0);
			amount1 = int256(balance1) - int256(_lastBalance1);		
			//!!
            _updateLastBalances(
                balance0,
                balance1);
            emit Swap( msg.sender, zeroForOne, amount, to);
        }
    }
///
///	ADD LIQUIDITY
///

	//  The proof of being LP is Ticket that stores information of how much liquidity was provided.
	//  It is minted when L is provided.
	//  It is burned when L is taken.

	function mint(
        address to,
        int24 lowestPositionIndex,
        int24 highestPositionIndex,
        uint256 positionValue)
        external
        returns(uint256 amount0 , uint256 amount1)
    {
        require(highestPositionIndex >= lowestPositionIndex);
        (uint256 _lastBalance0, uint256 _lastBalance1) = getTotalReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
		uint256 ticketID = _mint(to);
        int24 usingPosition = inUsePosition;   
		_ticketData[ticketID].lowestPositionIndex = lowestPositionIndex;
		_ticketData[ticketID].highestPositionIndex = highestPositionIndex;
		_ticketData[ticketID].positionValue = positionValue;

        if(lowestPositionIndex > usingPosition){
			//in this case positions.reserve1 should be 0
            uint256 range = uint256(int256(highestPositionIndex - lowestPositionIndex)) + 1;
            amount0 = range * positionValue;
            amount1 = 0;

            for(int24 i = lowestPositionIndex; i <= highestPositionIndex; i++){
                if (positions[i].activated == false) activate(i);    
                (uint256 reserve0, uint256 reserve1) = getPositionReserves(usingPosition); 
                (uint256 sqrtPriceBottom, uint256 sqrtPriceTop) = getPositionSqrtPrices(usingPosition);
                if(positions[i].supplyCoefficient != 0){
                    _ticketSupplyData[ticketID][i] = positions[i].supplyCoefficient*positionValue/reserve0;
                }
                else{
                    _ticketSupplyData[ticketID][i] = positionValue;
                }
                positions[i].supplyCoefficient += _ticketSupplyData[ticketID][i];
				//!!
                _addAddPositionReserves(i, positionValue, 0);                
            }
            //???
            require(balance0 >= _lastBalance0 + amount0 && balance1 >= _lastBalance1 + amount1, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
            //!!!
            emit Mint(to, ticketID, lowestPositionIndex, highestPositionIndex, positionValue, amount0, amount1);
            _updateLastBalances(
                balance0,
                balance1);
        }else if(highestPositionIndex < usingPosition)
        {
            // in this case positions.reserve0 should be 0
			amount0 = 0;
            amount1 = 0;
            for(int24 i = highestPositionIndex; i >= lowestPositionIndex; i--){
                if(positions[i].activated == false) activate(i);
                (uint256 reserve0, uint256 reserve1) = getPositionReserves(usingPosition); 
                (uint256 sqrtPriceBottom, uint256 sqrtPriceTop) = getPositionSqrtPrices(usingPosition);
                uint256 amount1ToAdd = positionValue /sqrtPositionMultiplier**2/10**36;
                amount1 += amount1ToAdd;
                if(positions[i].supplyCoefficient != 0){
                    _ticketSupplyData[ticketID][i] = positions[i].supplyCoefficient*amount1ToAdd/reserve1;
                }
                else{
					_ticketSupplyData[ticketID][i] = positionValue;
                }
                positions[i].supplyCoefficient += _ticketSupplyData[ticketID][i];
				//!!
                _addAddPositionReserves(i, 0, amount1ToAdd); 
            }
            //???
            require(balance0 >= _lastBalance0 + amount0 && balance1 >= _lastBalance1 + amount1, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
            emit Mint(to, ticketID, lowestPositionIndex, highestPositionIndex, positionValue, amount0, amount1);
            _updateLastBalances(
                balance0,
                balance1);
            
        }else
        {
            amount0 = uint256(int256(highestPositionIndex - inUsePosition)) * positionValue;
            amount1 = 0;


            for(int24 i = usingPosition + 1; i <= highestPositionIndex; i++){
                // in this cases positions.reserve1 should be 0
				if (positions[i].activated == false) activate(i);    
                (uint256 reserve0, uint256 reserve1) = getPositionReserves(usingPosition); 
                (uint256 sqrtPriceBottom, uint256 sqrtPriceTop) = getPositionSqrtPrices(usingPosition);
                if(positions[i].supplyCoefficient != 0){
                    _ticketSupplyData[ticketID][i] = positions[i].supplyCoefficient*positionValue/reserve0;
                }
                else{
                    _ticketSupplyData[ticketID][i] = positionValue;
                }
                positions[i].supplyCoefficient += _ticketSupplyData[ticketID][i];
				//!!
                _addAddPositionReserves(i, positionValue, 0);                 
            }

            for(int24 i = usingPosition - 1 ; i >= lowestPositionIndex; i--){
				// in this cases positions.reserve0 should be 0
                 if(positions[i].activated == false) activate(i);
                (uint256 reserve0, uint256 reserve1) = getPositionReserves(usingPosition); 
                (uint256 sqrtPriceBottom, uint256 sqrtPriceTop) = getPositionSqrtPrices(usingPosition);
				uint256 amount1ToAdd = positionValue /sqrtPositionMultiplier**2/10**36;
                amount1 += amount1ToAdd;
                if(positions[i].supplyCoefficient != 0){
                    _ticketSupplyData[ticketID][i] = positions[i].supplyCoefficient*amount1ToAdd/reserve1;
                }
                else{
                    _ticketSupplyData[ticketID][i] = positionValue;
                }
                positions[i].supplyCoefficient += _ticketSupplyData[ticketID][i];
				//!!
                _addAddPositionReserves(i, 0, amount1ToAdd); 
            }


            if(positions[usingPosition].activated == false) activate(usingPosition);
            (uint256 reserve0, uint256 reserve1) = getPositionReserves(usingPosition); 
            (uint256 sqrtPriceBottom, uint256 sqrtPriceTop) = getPositionSqrtPrices(usingPosition);
            uint256 amount0ToAdd = balance0 - lastBalance0 - amount0;
            uint256 amount1ToAdd = balance1 - lastBalance1 - amount1;
			uint256 price0 = _currentPrice(reserve0, reserve1, sqrtPriceBottom, sqrtPriceTop);
			uint256 price1 = _currentPrice(reserve0 +amount0ToAdd, reserve1 + amount1ToAdd, sqrtPriceBottom, sqrtPriceTop);
			require(amount0ToAdd + amount1ToAdd*price0 >= positionValue);
			require(amount0ToAdd + amount1ToAdd*price1 >= positionValue);
			amount0 += amount0ToAdd;
			amount1 += amount1ToAdd;

            if(positions[usingPosition].supplyCoefficient != 0){
				_ticketSupplyData[ticketID][usingPosition] = positions[usingPosition].supplyCoefficient * (amount0ToAdd + amount1ToAdd*price1)/(reserve0 + reserve1*price1);             
            } else 
            {
                _ticketSupplyData[ticketID][usingPosition] = positionValue;                
            }
            //!!
			positions[usingPosition].supplyCoefficient += _ticketSupplyData[ticketID][usingPosition];
			//!!
            _addAddPositionReserves(usingPosition, amount0ToAdd, amount1ToAdd); 
            //??
            require(balance0 >= _lastBalance0 + amount0 && balance1 >= _lastBalance1 + amount1, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
            emit Mint(to, ticketID, lowestPositionIndex, highestPositionIndex, positionValue, amount0, amount1);
            _updateLastBalances(
                balance0,
                balance1);
        }
    }

///
///	REDEEM LIQ
///
}
