// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./library/PoolHelper.sol";
import "./library/IERC20.sol";
import "./library/Ticket.sol";

contract Pool is PoolHelper, Ticket
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
		highestActivatedPosition = 0;
		lowestActivatedPosition = 0;
		inUsePosition = 0;
	}

	event SwapInPosition(address msgSender, int24 index, bool zeroForOne, uint256 amountIn, uint256 amountOut, address to);
	event PositionActivated(int24 index);
	event InUsePositionChanged(int24 index);
	event Swap( address msgSender, bool zeroForOne, int256 amount, address to);
	event Mint(address to, uint256 ticketID, int24 lowestPositionIndex, int24 highestPositionIndex, uint256 positionValue, uint256 amount0, uint256 amount1);
	event Burn(address owner, uint256 ticketID, int24 lowestPositionIndex, int24 highestPositionIndex, uint256 positionValue, uint256 amount0Transfered, uint256 amount1Transfered);
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

	struct swapInPositionData{
		int24 index;
		address to;
		bool zeroForOne;
		uint256 amountOut;
		uint256 reserve0;
		uint256 reserve1;
		uint256 balance0;
		uint256 balance1;
	}
	function _swapInPosition(
        int24 index,
        address to,
        bool zeroForOne,
        uint256 amountOut) private returns( uint256 amountIn)
    {
        require(index == inUsePosition, 'DesireSwapV0: WRONG_INDEX');
		swapInPositionData memory help = swapInPositionData({index: index, to: to, zeroForOne: zeroForOne, amountOut: amountOut,
			reserve0: 0, reserve1: 0, balance0: 0, balance1: 0});
        (help.reserve0, help.reserve1) = getPositionReserves(help.index);
        (uint256 _lastBalance0, uint256 _lastBalance1) = getLastBalances();
        (uint256 sqrtBottom, uint256 sqrtTop) = getPositionSqrtPrices(help.index);
        uint256 L = LiqCoefficient(help.reserve0, help.reserve1, sqrtBottom, sqrtTop);
        uint256 collectedFee;
        address _token0 = token0;
        address _token1 = token1;

        require( ( help.zeroForOne == true && help.amountOut <= help.reserve1) ||
                 ( help.zeroForOne == false && help.amountOut <= help.reserve0), 'DesireSwapV0: INSUFFICIENT_POSITION_LIQUIDITY');

        // token0 for token1 // token0 in; token1 out;
        if( help.zeroForOne) {
            // !!!
            _safeTransfer(_token1, help.to, help.amountOut);
            uint256 amountInHelp = _amountIn(help.zeroForOne, help.reserve0, help.reserve1, sqrtBottom, sqrtTop, help.amountOut, L); // do not include fees;
            uint256 collectedProtocolFee = 0;
            amountIn = amountInHelp*10**36/(10**36 - feePercentage);
            collectedFee = amountIn - amountInHelp;
            if (protocolFeeIsOn){
                collectedProtocolFee = (collectedFee * protocolFeePercentage)/10**36;
                //!!
                collectedProtocolFee0 += collectedProtocolFee;
            }

            //??
            require(LiqCoefficient(help.reserve0 + amountIn - collectedFee, help.reserve1 - help.amountOut, sqrtBottom, sqrtTop) >= L,
             'DesireSwapV0: LIQ_COEFFICIENT_IS_TO_LOW'); //assure that after swap there is more or equal liquidity. If _amountIn works correctly it can be removed.

            //!!
            _addSubPositionReserves(
                help.index,
                amountIn - collectedProtocolFee,
                help.amountOut);

            help.reserve1 = positions[help.index].reserve1;
            if( help.reserve1 == 0){
                inUsePosition--; // to powiina robic funckja
                emit InUsePositionChanged(help.index+1);
            }

            help.balance0 = IERC20(token0).balanceOf(address(this));
            help.balance1 = IERC20(token1).balanceOf(address(this));            
            //???
            require(help.balance0 >= _lastBalance0 + amountIn && help.balance1 >= _lastBalance1 - help.amountOut, 'DesireSwapV0: TO_LOW_BALANCES');
            //!!!
            _updateLastBalances(
                _lastBalance0 + amountIn,
                _lastBalance1 - help.amountOut);

        }
        // token1 for token0 // token1 in; token0 out;
        if( help.zeroForOne == false) {
            //!!!
            _safeTransfer(_token0, help.to, help.amountOut);
            uint256 amountInHelp = _amountIn(help.zeroForOne, help.reserve0, help.reserve1, sqrtBottom, sqrtTop, help.amountOut, L); // do not include fees;
            uint256 collectedProtocolFee = 0;
            amountIn = amountInHelp*10**36/(10**36 - feePercentage);
            collectedFee = amountIn - amountInHelp;

            if (protocolFeeIsOn){
                collectedProtocolFee = (collectedFee * protocolFeePercentage)/10**36;
                //!!
                collectedProtocolFee1 += collectedProtocolFee;
            }
            
            //??
            require(LiqCoefficient(help.reserve0 - help.amountOut, help.reserve1 + amountIn - collectedFee, sqrtBottom, sqrtTop) >= L,
            'DesireSwapV0: LIQ_COEFFICIENT_IS_TO_LOW'); //assure that after swao there is more or equal liquidity. If _amountIn works correctly it can be removed.
            
            //!!
            _subAddPositionReserves(
                help.index,
                help.amountOut,
                amountIn - collectedProtocolFee);

            help.reserve0 = positions[help.index].reserve0;
            //??
            if( help.reserve0 == 0){
                inUsePosition++;   // to powinna robic funkcja
                emit InUsePositionChanged(help.index-1);
            }

            help.balance0 = IERC20(token0).balanceOf(address(this));
            help.balance1 = IERC20(token1).balanceOf(address(this));   
            //??
            require(help.balance0 >= _lastBalance0 -help.amountOut && help.balance1 >= _lastBalance1 + amountIn, 'DesireSwapV0: TO_LOW_BALANCES');
            //!!
            _updateLastBalances(
                _lastBalance0 - help.amountOut,
                _lastBalance1 + amountIn);
        }
        emit SwapInPosition(msg.sender, help.index, help.zeroForOne, amountIn, help.amountOut, help.to);
		delete help;
    }


	// This function uses swapInPosition to make any swap.
    // The calldata is not yet used. SwapRoutes!!!!!!!
    // amount > 0 amount is exact token inflow, amount < 0 amount is exact token outflow.
    // sqrtPriceLimit is price
    struct swapData{
		address to;
		bool zeroForOne;
		int256 amount;
		int256 amount0;
		int256 amount1;
		uint256 balance0;
		uint256 balance1;
		uint256 usingReserve;
		uint256 remained;
		uint256 reserve0;
		uint256 reserve1;
		uint256 sqrtBottom;
		uint256 sqrtTop;
	}
	function swap(
        address to,
        bool zeroForOne,
        int256 amount //,
        //uint256 sqrtPriceLimit,
        //bytes calldata data
    ) external returns (int256, int256)
    {        
        swapData memory data = 
		swapData({to: to, zeroForOne: zeroForOne, amount: amount, amount0: 0, amount1: 0,
			balance0: 0, balance1: 0, usingReserve: 0, remained: 0, reserve0: 0, reserve1: 0,
			sqrtBottom: 0, sqrtTop: 0});
		(uint256 _lastBalance0, uint256 _lastBalance1) = getLastBalances();
        uint256 amountRecieved =0;
        int24 usingPosition = inUsePosition;
        
        //
        // tokensForExactTokens
        //
        // token0 In, token1 Out, tokensForExactTokens
        if( data.zeroForOne && data.amount < 0 && uint256(-data.amount) <= totalReserve1){
            data.remained = uint256(-data.amount);
            data.usingReserve = positions[usingPosition].reserve1;        
            while( data.remained > data.usingReserve) {
                amountRecieved += _swapInPosition( usingPosition, data.to, true, data.usingReserve);
                data.remained -= data.usingReserve;
                usingPosition = inUsePosition;
                data.usingReserve = positions[usingPosition].reserve1;
            }
            amountRecieved +=_swapInPosition( usingPosition, to, true, data.remained);
            data.balance0 = IERC20(token0).balanceOf(address(this));
            data.balance1 = IERC20(token1).balanceOf(address(this));
            //??? Aditional safety check!
            require( data.balance0 >= _lastBalance0 + amountRecieved && data.balance1 >= _lastBalance1 - uint256(-data.amount),
                    'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');
			data.amount0 = int256(data.balance0) - int256(_lastBalance0);
			data.amount1 = int256(data.balance1) - int256(_lastBalance1);
			_updateLastBalances(data.balance0, data.balance1);
            emit Swap( msg.sender, true, data.amount, data.to);
        }

        // token1 In, token0 Out, tokensForExactTokens
        else if( data.zeroForOne == false && data.amount < 0 && uint256(-data.amount) <= lastBalance0){
            data.remained = uint256(-data.amount);
            data.usingReserve = positions[usingPosition].reserve0;        
            while( data.remained > data.usingReserve) {
                amountRecieved += _swapInPosition( usingPosition, data.to, false, data.usingReserve);
                data.remained -= data.usingReserve;
                usingPosition = inUsePosition;
                data.usingReserve = positions[usingPosition].reserve0;
            }
            amountRecieved +=_swapInPosition( usingPosition, data.to, false, data.remained);
            data.balance0 = IERC20(token0).balanceOf(address(this));
            data.balance1 = IERC20(token1).balanceOf(address(this));
            //??? Aditional safety check!
            require( data.balance1 >= _lastBalance1 + amountRecieved && data.balance0 >= _lastBalance0 - uint256(-data.amount),
                    'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');
			data.amount0 = int256(data.balance0) - int256(_lastBalance0);
			data.amount1 = int256(data.balance1) - int256(_lastBalance1);
            //!!
			_updateLastBalances(data.balance0, data.balance1);
            emit Swap( msg.sender, false, data.amount, data.to);
        } 


        //
        //  exactTokensForTokens
        //
        // token0 In, token1 Out, exactTokensForTokens
        else if( data.zeroForOne && data.amount > 0){
            data.remained = uint256(data.amount);
            uint256 predictedFee = data.remained *feePercentage/10**18;
            (data.reserve0, data.reserve1) = getPositionReserves(usingPosition); 
            (data.sqrtBottom, data.sqrtTop) = getPositionSqrtPrices(usingPosition); 
            uint256 L = LiqCoefficient( data.reserve0, data.reserve1, data.sqrtBottom, data.sqrtTop);
            uint256 amountSend =0;
            uint256 amountOut = _amountOut(true, data.reserve0, data.reserve1, data.sqrtBottom, data.sqrtTop, data.remained-predictedFee, L);
            while( amountOut >= data.reserve1) {
                data.remained -= _swapInPosition(usingPosition, data.to, true, data.reserve1);
                usingPosition++;
                amountSend +=data.reserve1;
                predictedFee = data.remained *feePercentage/10**18;
                (data.reserve0, data.reserve1) = getPositionReserves(usingPosition);
                (data.sqrtBottom, data.sqrtTop) = getPositionSqrtPrices(usingPosition);
                L = LiqCoefficient( data.reserve0, data.reserve1, data.sqrtBottom, data.sqrtTop);
                amountOut = _amountOut(true, data.reserve0, data.reserve1, data.sqrtBottom, data.sqrtTop, data.remained-predictedFee, L);
            }
            data.remained -= _swapInPosition(usingPosition, data.to, true, amountOut);
            amountSend +=amountOut;

            data.balance0 = IERC20(token0).balanceOf(address(this));
            data.balance1 = IERC20(token1).balanceOf(address(this));
            //?? Aditional safety check!
            require( data.balance0 >= _lastBalance0 + uint256(data.amount) && data.balance1 >= _lastBalance1 - amountSend,
                    'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');
            
			data.amount0 = int256(data.balance0) - int256(_lastBalance0);
			data.amount1 = int256(data.balance1) - int256(_lastBalance1);
			//!!
			_updateLastBalances(data.balance0, data.balance1);
            emit Swap( msg.sender, true, data.amount, data.to);
        }
        
        // token1 In, token0 Out, exactTokensForTokens
        else if( data.zeroForOne == false && data.amount > 0){
            data.remained = uint256(data.amount);
            uint256 predictedFee = data.remained *feePercentage/10**18;
            (data.reserve0, data.reserve1) = getPositionReserves(usingPosition); 
            (data.sqrtBottom, data.sqrtTop) = getPositionSqrtPrices(usingPosition);
            uint256 L = LiqCoefficient( data.reserve0, data.reserve1, data.sqrtBottom, data.sqrtTop);
            uint256 amountSend =0;
            uint256 amountOut = _amountOut(false, data.reserve0, data.reserve1, data.sqrtBottom, data.sqrtTop, data.remained-predictedFee, L);
            while( amountOut >= data.reserve0) {
                data.remained -= _swapInPosition(usingPosition, data.to, false, data.reserve0);
                usingPosition++;
                amountSend += data.reserve0;
                predictedFee = data.remained *feePercentage/10**18;
                (data.reserve0, data.reserve1) = getPositionReserves(usingPosition);
                (data.sqrtBottom, data.sqrtTop) = getPositionSqrtPrices(usingPosition);
                L = LiqCoefficient( data.reserve0, data.reserve1, data.sqrtBottom, data.sqrtTop);
                amountOut = _amountOut(false, data.reserve0, data.reserve1, data.sqrtBottom, data.sqrtTop, data.remained-predictedFee, L);
            }
            data.remained -= _swapInPosition(usingPosition, data.to, false, amountOut);
            amountSend +=amountOut;

            data.balance0 = IERC20(token0).balanceOf(address(this));
            data.balance1 = IERC20(token1).balanceOf(address(this));
            //?? Aditional safety check!
            require( data.balance0 >= _lastBalance0 - amountSend  && data.balance1 >= _lastBalance1 + uint256(data.amount),
                    'DesireSwapV0: SWAP_HAS_FAILED._BALANCES_ARE_TO_SMALL');

			data.amount0 = int256(data.balance0) - int256(_lastBalance0);
			data.amount1 = int256(data.balance1) - int256(_lastBalance1);		
			//!!
            _updateLastBalances(data.balance0, data.balance1);
            emit Swap( msg.sender, false, data.amount, data.to);
        }
		int256 amount0 = data.amount0;
		int256 amount1 = data.amount1;
		delete data;
		return (amount0, amount1);
    }
///
///	ADD LIQUIDITY
///

	//  The proof of being LP is Ticket that stores information of how much liquidity was provided.
	//  It is minted when L is provided.
	//  It is burned when L is taken.

	struct mintData{
		address to;
        int24 lowestPositionIndex;
        int24 highestPositionIndex;
        uint256 positionValue;
		uint256 balance0;
		uint256 balance1;
		uint256 ticketID;
		uint256 reserve0;
		uint256 reserve1;
		uint256 sqrtPriceBottom;
		uint256 sqrtPriceTop;
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
		mintData memory help = mintData({to: to, lowestPositionIndex: lowestPositionIndex, highestPositionIndex: highestPositionIndex, positionValue: positionValue,
			balance0: 0, balance1: 0, ticketID: 0, reserve0: 0, reserve1: 0, sqrtPriceBottom: 0, sqrtPriceTop: 0});
        (uint256 _lastBalance0, uint256 _lastBalance1) = getTotalReserves();
        help.balance0 = IERC20(token0).balanceOf(address(this));
        help.balance1 = IERC20(token1).balanceOf(address(this));
		help.ticketID = _mint(help.to);
        int24 usingPosition = inUsePosition;   
		_ticketData[help.ticketID].lowestPositionIndex = help.lowestPositionIndex;
		_ticketData[help.ticketID].highestPositionIndex = help.highestPositionIndex;
		_ticketData[help.ticketID].positionValue = help.positionValue;


        if(help.lowestPositionIndex > usingPosition){
			//in this case positions.reserve1 should be 0
            uint256 range = uint256(int256(help.highestPositionIndex - help.lowestPositionIndex)) + 1;
            amount0 = range * help.positionValue;
            amount1 = 0;

            for(int24 i = help.lowestPositionIndex; i <= help.highestPositionIndex; i++){
                if (positions[i].activated == false) activate(i);    
                (help.reserve0, help.reserve1) = getPositionReserves(usingPosition); 
                (help.sqrtPriceBottom, help.sqrtPriceTop) = getPositionSqrtPrices(usingPosition);
                if(positions[i].supplyCoefficient != 0){
                    _ticketSupplyData[help.ticketID][i] = positions[i].supplyCoefficient*help.positionValue/help.reserve0;
                }
                else{
                    _ticketSupplyData[help.ticketID][i] = help.positionValue;
                }
                positions[i].supplyCoefficient += _ticketSupplyData[help.ticketID][i];
				//!!
                _addAddPositionReserves(i, help.positionValue, 0);                
            }
            //???
            require(help.balance0 >= _lastBalance0 + amount0 && help.balance1 >= _lastBalance1 + amount1, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
            //!!!
            emit Mint(help.to, help.ticketID, help.lowestPositionIndex, help.highestPositionIndex, help.positionValue, amount0, amount1);
            _updateLastBalances(help.balance0, help.balance1);
        }else if(help.highestPositionIndex < usingPosition)
        {
            // in this case positions.reserve0 should be 0
			amount0 = 0;
            amount1 = 0;
            for(int24 i = help.highestPositionIndex; i >= help.lowestPositionIndex; i--){
                if(positions[i].activated == false) activate(i);
                (help.reserve0, help.reserve1) = getPositionReserves(usingPosition); 
                (help.sqrtPriceBottom, help.sqrtPriceTop) = getPositionSqrtPrices(usingPosition);
                uint256 amount1ToAdd = help.positionValue /sqrtPositionMultiplier**2/10**36;
                amount1 += amount1ToAdd;
                if(positions[i].supplyCoefficient != 0){
                    _ticketSupplyData[help.ticketID][i] = positions[i].supplyCoefficient*amount1ToAdd/help.reserve1;
                }
                else{
					_ticketSupplyData[help.ticketID][i] = help.positionValue;
                }
                positions[i].supplyCoefficient += _ticketSupplyData[help.ticketID][i];
				//!!
                _addAddPositionReserves(i, 0, amount1ToAdd); 
            }
            //???
            require(help.balance0 >= _lastBalance0 + amount0 && help.balance1 >= _lastBalance1 + amount1, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
            emit Mint(help.to, help.ticketID, help.lowestPositionIndex, help.highestPositionIndex, help.positionValue, amount0, amount1);
            _updateLastBalances(help.balance0, help.balance1);
            
        }else
        {
            amount0 = uint256(int256(help.highestPositionIndex - inUsePosition)) * help.positionValue;
            amount1 = 0;
			uint256 amount0ToAdd;
			uint256 amount1ToAdd;

            for(int24 i = usingPosition + 1; i <= help.highestPositionIndex; i++){
                // in this cases positions.reserve1 should be 0
				if (positions[i].activated == false) activate(i);    
                (help.reserve0, help.reserve1) = getPositionReserves(usingPosition); 
                (help.sqrtPriceBottom, help.sqrtPriceTop) = getPositionSqrtPrices(usingPosition);
                if(positions[i].supplyCoefficient != 0){
                    _ticketSupplyData[help.ticketID][i] = positions[i].supplyCoefficient*help.positionValue/help.reserve0;
                }
                else{
                    _ticketSupplyData[help.ticketID][i] = help.positionValue;
                }
                positions[i].supplyCoefficient += _ticketSupplyData[help.ticketID][i];
				//!!
                _addAddPositionReserves(i, help.positionValue, 0);                 
            }
			
			for(int24 i = usingPosition - 1; i >= help.lowestPositionIndex; i--){
				// in this cases positions.help.reserve0 should be 0
                 if(positions[i].activated == false) activate(i);
                (help.reserve0, help.reserve1) = getPositionReserves(usingPosition); 
                (help.sqrtPriceBottom, help.sqrtPriceTop) = getPositionSqrtPrices(usingPosition);
				amount1ToAdd = help.positionValue /sqrtPositionMultiplier**2/10**36;
                amount1 += amount1ToAdd;
                if(positions[i].supplyCoefficient != 0){
                    _ticketSupplyData[help.ticketID][i] = positions[i].supplyCoefficient*amount1ToAdd/help.reserve1;
                }
                else{
                    _ticketSupplyData[help.ticketID][i] = help.positionValue;
                }
                positions[i].supplyCoefficient += _ticketSupplyData[help.ticketID][i];
				//!!
                _addAddPositionReserves(i, 0, amount1ToAdd); 
            }


            if(positions[usingPosition].activated == false) activate(usingPosition);
            (help.reserve0, help.reserve1) = getPositionReserves(usingPosition); 
            (help.sqrtPriceBottom, help.sqrtPriceTop) = getPositionSqrtPrices(usingPosition);
            amount0ToAdd = help.balance0 - lastBalance0 - amount0;
            amount1ToAdd = help.balance1 - lastBalance1 - amount1;
			uint256 price0 = _currentPrice(help.reserve0, help.reserve1, help.sqrtPriceBottom, help.sqrtPriceTop);
			uint256 price1 = _currentPrice(help.reserve0 +amount0ToAdd, help.reserve1 + amount1ToAdd, help.sqrtPriceBottom, help.sqrtPriceTop);
			require(amount0ToAdd + amount1ToAdd*price0 >= help.positionValue);
			require(amount0ToAdd + amount1ToAdd*price1 >= help.positionValue);
			amount0 += amount0ToAdd;
			amount1 += amount1ToAdd;

            if(positions[usingPosition].supplyCoefficient != 0){
				_ticketSupplyData[help.ticketID][usingPosition] = positions[usingPosition].supplyCoefficient * (amount0ToAdd + amount1ToAdd*price1)/(help.reserve0 + help.reserve1*price1);             
            } else 
            {
                _ticketSupplyData[help.ticketID][usingPosition] = help.positionValue;                
            }
            //!!
			positions[usingPosition].supplyCoefficient += _ticketSupplyData[help.ticketID][usingPosition];
			//!!
            _addAddPositionReserves(usingPosition, amount0ToAdd, amount1ToAdd); 
            //??
            require(help.balance0 >= _lastBalance0 + amount0 && help.balance1 >= _lastBalance1 + amount1, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
            emit Mint(help.to, help.ticketID, help.lowestPositionIndex, help.highestPositionIndex, help.positionValue, amount0, amount1);
            _updateLastBalances(help.balance0, help.balance1);
        }
    }

///
///	REDEEM LIQ
///

	struct burnData{
		uint256 amount0ToTransfer;
		uint256 amount1ToTransfer;
		uint256 supply;
		uint256 amount0ToTransferHelp;
		uint256 amount1ToTransferHelp;
	}
	function burn (address to, uint256 ticketID) external{
		require( _exists(ticketID), 'DesireSwapV0: THE_ERC721_DO_NOT_EXISTS');
		address owner = Ticket.ownerOf(ticketID);
		require( tx.origin == owner,'DesireSwapV0: THE_TX.ORIGIN_IS_NOT_THE_OWNER');
		_burn(ticketID);

		(uint256 _lastBalance0, uint256 _lastBalance1) = getLastBalances();
		int24 usingPosition = inUsePosition;
			
		TicketData memory data = _ticketData[ticketID];
		int24 highestPositionIndex = data.highestPositionIndex;
		int24 lowestPositionIndex = data.lowestPositionIndex;
		burnData memory help;
		uint256 balance0;
		uint256 balance1;

		if(lowestPositionIndex > usingPosition){
			for(int24 i = lowestPositionIndex; i <= highestPositionIndex; i++){
				help.supply = _ticketSupplyData[ticketID][i];
				help.amount0ToTransferHelp = help.supply*positions[i].reserve0/positions[i].supplyCoefficient;
				help.amount0ToTransfer += help.amount0ToTransferHelp;
				//!!
				_subSubPositionReserves(i, help.amount0ToTransferHelp, 0);
				//!!
				positions[i].supplyCoefficient -= help.supply;
			}
				//!!!
				_safeTransfer(token0, to, help.amount0ToTransfer);
				balance0 = IERC20(token0).balanceOf(address(this));
				balance1 = IERC20(token1).balanceOf(address(this));
				//???
				require(balance0 >= _lastBalance0 - help.amount0ToTransfer && balance1 >= _lastBalance1, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
				emit Burn(owner, ticketID, lowestPositionIndex, highestPositionIndex, data.positionValue, help.amount0ToTransfer, help.amount1ToTransfer);
				//!!!
				_updateLastBalances(balance0, balance1);
		} else if(highestPositionIndex > usingPosition){
			for(int24 i = highestPositionIndex; i >= lowestPositionIndex; i--){
				help.supply = _ticketSupplyData[ticketID][i];
				help.amount1ToTransferHelp = help.supply*positions[i].reserve1/positions[i].supplyCoefficient;
				help.amount1ToTransfer += help.amount1ToTransferHelp;
				//!!
				_subSubPositionReserves(i, 0, help.amount1ToTransfer);
				//!!
				positions[i].supplyCoefficient -= help.supply;
			}
			//!!!
			_safeTransfer(token1, to, help.amount1ToTransfer);
			balance0 = IERC20(token0).balanceOf(address(this));
			balance1 = IERC20(token1).balanceOf(address(this));
			//???
			require(balance0 >= _lastBalance0 && balance1 >= _lastBalance1 - help.amount1ToTransfer, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
			emit Burn(owner, ticketID, lowestPositionIndex, highestPositionIndex, data.positionValue, help.amount0ToTransfer, help.amount1ToTransfer);
			//!!!
			_updateLastBalances(balance0, balance1);
		} else
		{
			for(int24 i = lowestPositionIndex; i < usingPosition; i++){
				help.supply = _ticketSupplyData[ticketID][i];
				help.amount0ToTransferHelp = help.supply*positions[i].reserve0/positions[i].supplyCoefficient;
				help.amount0ToTransfer += help.amount0ToTransferHelp;
				//!!
				_subSubPositionReserves(i, help.amount0ToTransferHelp, 0);
				//!!
				positions[i].supplyCoefficient -= help.supply;
			}
			for(int24 i = highestPositionIndex; i > usingPosition; i--){
				help.supply = _ticketSupplyData[ticketID][i];
				help.amount1ToTransferHelp = help.supply*positions[i].reserve1/positions[i].supplyCoefficient;
				help.amount1ToTransfer += help.amount1ToTransferHelp;
				//!!
				_subSubPositionReserves(i, 0, help.amount1ToTransfer);
				//!!
				positions[i].supplyCoefficient -= help.supply;
			}
				
			help.supply = _ticketSupplyData[ticketID][usingPosition];
			help.amount0ToTransferHelp = help.supply*positions[usingPosition].reserve0/positions[usingPosition].supplyCoefficient;
			help.amount1ToTransferHelp = help.supply*positions[usingPosition].reserve1/positions[usingPosition].supplyCoefficient;
			help.amount0ToTransfer += help.amount0ToTransferHelp;
			help.amount1ToTransfer += help.amount1ToTransferHelp;
			_subSubPositionReserves(usingPosition, help.amount0ToTransferHelp, help.amount1ToTransferHelp);
			positions[usingPosition].supplyCoefficient -= help.supply;

			//!!!
			_safeTransfer(token0, to, help.amount0ToTransfer);
			_safeTransfer(token1, to, help.amount1ToTransfer);

			balance0 = IERC20(token0).balanceOf(address(this));
			balance1 = IERC20(token1).balanceOf(address(this));
			//???
			require(balance0 >= _lastBalance0 - help.amount0ToTransfer && balance1 >= _lastBalance1 - help.amount1ToTransfer, 'DesireSwapV0: BALANCES_ARE_TO_LOW');
			
			emit Burn(owner, ticketID, lowestPositionIndex, highestPositionIndex, data.positionValue, help.amount0ToTransfer, help.amount1ToTransfer);
			//!!!
			_updateLastBalances(balance0, balance1);
		}
	}
}