// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./Ticket.sol";
import "./libraries/PoolHelper.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IERC20.sol";
import './interfaces/IDesireSwapV0Factory.sol';
import './interfaces/IDesireSwapV0Pool.sol';

import "./interfaces/callback/IDesireSwapV0MintCallback.sol";
import "./interfaces/callback/IDesireSwapV0SwapCallback.sol";
import "./interfaces/callback/IDesireSwapV0FlashCallback.sol";

contract DesireSwapV0Pool is Ticket, IDesireSwapV0Pool {
	bool public override initialized;
	bool constant public override protocolFeeIsOn = false;

	address public immutable override factory;
	address public immutable override token0;
	address public immutable override token1;

	uint256 private constant D = 10**18;
	uint256 private constant DD = 10**36;
	uint256 public immutable override sqrtRangeMultiplier;   // example: 100100000.... is 1.001 (* 10**36)
	uint256 public constant override feePercentage = 0;            //  0 fee is 0 // 100% fee is 1* 10**36;
	uint256 public constant protocolFeePart = 0;
	uint256 private totalReserve0;
	uint256 private totalReserve1;
	uint256 private lastBalance0;
	uint256 private lastBalance1;

	struct Range {
		uint256 reserve0;
		uint256 reserve1;
		uint256 sqrtPriceBottom;    //  sqrt(lower position bound price) * 10**18 // price of token1 in token0 for 1 token0 i get priceBottom of tokens1
		uint256 sqrtPriceTop;
		uint256 supplyCoefficient; 	//
		bool activated;
	}

    mapping(int24 => Range) private ranges;

    int24 private inUseRange;
	int24 private highestActivatedRange;
	int24 private lowestActivatedRange;

	constructor(
		address _factory,
		address _token0, address _token1,
		 uint256 _sqrtRangeMultiplier
	){
		initialized = false;
		factory = _factory;
		token0 = _token0;
		token1 = _token1;
		sqrtRangeMultiplier = _sqrtRangeMultiplier;
	}

///
/// VIEW
///
	function balance0()
	public override view
	returns(uint256)
	{
		return IERC20(token0).balanceOf(address(this));
	}

	function balance1()
	public override view
	returns(uint256)
	{
		return IERC20(token1).balanceOf(address(this));
	}
	
	function getLastBalances()
	external override view
	returns (uint256 _lastBalance0, uint256 _lastBalance1)
	{
		_lastBalance0 = lastBalance0;
		_lastBalance1 = lastBalance1;
	}

	function getTotalReserves() 
	external override view
	returns (uint256 _totalReserve0, uint256 _totalReserve1)
	{
		_totalReserve0 = totalReserve0;
		_totalReserve1 = totalReserve1;
	}

	function getRangeInfo(int24 index) 
	public override view
	returns (uint256 _reserve0, uint256 _reserve1, uint256 _sqrtPriceBottom, uint256 _sqrtPriceTop)
	{
		_reserve0 = ranges[index].reserve0;
		_reserve1 = ranges[index].reserve1;
		_sqrtPriceBottom = ranges[index].sqrtPriceBottom;
		_sqrtPriceTop = ranges[index].sqrtPriceTop;
	}

///
/// PRIVATE
///

	function _updateLastBalances(
		uint256 _lastBalance0,
		uint256 _lastBalance1)
	private
	{
		lastBalance0 = _lastBalance0;
		lastBalance1 = _lastBalance1;
	}

    function _modifyRangeReserves(
		int24 index,
		uint256 toAdd0,
        uint256 toAdd1,
		bool add0, /// add or substract
        bool add1)
	private
	{
		ranges[index].reserve0 = add0 ? ranges[index].reserve0 + toAdd0 : ranges[index].reserve0 - toAdd0;
		ranges[index].reserve1 = add1 ? ranges[index].reserve1 + toAdd1 : ranges[index].reserve1 - toAdd1;
		totalReserve0 = add0 ? totalReserve0 + toAdd0: totalReserve0 - toAdd0;
		totalReserve1 = add1 ? totalReserve1 + toAdd0: totalReserve1 - toAdd1;        

		if(ranges[index].reserve0 == 0 && ranges[index-1].activated) {
            inUseRange++;
            emit InUseRangeChanged(index+1);
        }
		if(ranges[index].reserve1 == 0 && ranges[index+1].activated) {
            inUseRange--;
            emit InUseRangeChanged(index-1);
        }
	}
///
/// Range activation
///
	function activate(int24 index)
	private
	{
		require(!ranges[index].activated, 'DesireSwapV0: POSITION_ALREADY_ACTIVATED');
		if(index > highestActivatedRange) {
			highestActivatedRange = index;
			if(!ranges[index-1].activated)	// shouldnt be another way around as we try to exceed the highest position? (index+1)
				activate(index-1);
			ranges[index].sqrtPriceBottom = ranges[index-1].sqrtPriceTop;
			ranges[index].sqrtPriceTop = ranges[index].sqrtPriceBottom * sqrtRangeMultiplier / D;
		}
		else if(index < lowestActivatedRange) {
			lowestActivatedRange = index;
			if(!ranges[index+1].activated)	// shouldnt be another way around as we try to exceed the lowest position? (index-1)
				activate(index+1);
			ranges[index].sqrtPriceTop = ranges[index+1].sqrtPriceBottom;
			ranges[index].sqrtPriceBottom = ranges[index].sqrtPriceTop * D / sqrtRangeMultiplier;
		}
		ranges[index].activated = true;
		emit RangeActivated(index);
	}


///
/// POOL ACTIONS
///

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

	/// help function
	function _swapInRange(
        int24 index,
        address to,
        bool zeroForOne,
        uint256 amountOut)
	private
	returns( uint256 amountIn)
    {
        require(index == inUseRange, 'DesireSwapV0: WRONG_INDEX');
		helpData memory h = helpData({
			lastBalance0: lastBalance0, lastBalance1: lastBalance1,
			balance0: 0, balance1: 0,
			value00: ranges[index].reserve0, value01: ranges[index].reserve1,
			value10: ranges[index].sqrtPriceBottom, value11: ranges[index].sqrtPriceTop
		});
        require((zeroForOne  && amountOut <= h.value01) ||
                (!zeroForOne && amountOut <= h.value00), 'DesireSwapV0: INSUFFICIENT_POSITION_LIQUIDITY');        
		
        uint256 collectedFee;
		uint256 amountInHelp = PoolHelper.AmountIn(zeroForOne, h.value00, h.value01, h.value10, h.value11, amountOut); // do not include fees;
        uint256 collectedProtocolFee = 0;

        amountIn = amountInHelp*D/(D - feePercentage);
        collectedFee = amountIn - amountInHelp;
        if (protocolFeeIsOn)
            collectedProtocolFee = (collectedFee * protocolFeePart)/D;
        // token0 for token1 // token0 in; token1 out;
        if(zeroForOne) {
            //??
            require(PoolHelper.LiqCoefficient(h.value00 + amountInHelp, h.value01 - amountOut, h.value10, h.value11)
				>= PoolHelper.LiqCoefficient(h.value00, h.value01, h.value10, h.value11),
             'DesireSwapV0: LIQ_COEFFICIENT_IS_TOO_LOW'); //assure that after swap there is more or equal liquidity. If PoolHelper.AmountIn works correctly it can be removed.
            //!!
            _modifyRangeReserves(
                index,
                amountIn - collectedProtocolFee,
                amountOut, true, false);
        }
        // token1 for token0 // token1 in; token0 out;
        else {    
            //??
            require(PoolHelper.LiqCoefficient(h.value00 - amountOut, h.value01 + amountInHelp, h.value00, h.value11) 
				>= PoolHelper.LiqCoefficient(h.value00, h.value01, h.value10, h.value11),
            'DesireSwapV0: LIQ_COEFFICIENT_IS_TOO_LOW'); //assure that after swao there is more or equal liquidity. If PoolHelper.AmountIn works correctly it can be removed.            
            //!!
            _modifyRangeReserves(
                index,
                amountOut,
                amountIn - collectedProtocolFee, false, true);
        }
        emit SwapInRange(msg.sender, index, zeroForOne, amountIn, amountOut, to);
		delete h;
    }


	// This function uses swapInRange to make any swap.
    // The calldata is not yet used. SwapRoutes!!!!!!!
    // amount > 0 amount is exact token inflow, amount < 0 amount is exact token outflow.
    // sqrtPriceLimit is price

	struct swapParams{
		address to;
        bool zeroForOne;
        int256 amount;
        uint256 sqrtPriceLimit;
        bytes data;
	}

	function swap(
        address to,
        bool zeroForOne,
        int256 amount,
        uint256 sqrtPriceLimit,
        bytes calldata data)
	external override 
	returns (int256, int256)
    {        
        swapParams memory s= swapParams({
			to: to, zeroForOne: zeroForOne,
			amount: amount, sqrtPriceLimit: sqrtPriceLimit,
			data: data
		});
		helpData memory h = helpData({
			lastBalance0: lastBalance0, lastBalance1: lastBalance1,
			balance0: 0, balance1: 0,
			value00: 0, value01: 0,
			value10: 0, value11: 0});
		uint256 usingReserve;
        uint256 amountRecieved;
		uint256 amountSend;
		uint256 remained;
        int24 usingRange = inUseRange;
        
        //
        // tokensForExactTokens
        //
        // token0 In, token1 Out, tokensForExactTokens
        if(s.amount <= 0){
            remained = uint256(-s.amount);
            if( s.zeroForOne){
                require(remained <= totalReserve1);
                usingReserve = ranges[usingRange].reserve1;        
            }
            // token1 In, token0 Out, tokensForExactTokens
            else{
                require(remained <= totalReserve0);
                usingReserve = ranges[usingRange].reserve0;        
            }
            while( remained > usingReserve && 
				(s.zeroForOne ? sqrtPriceLimit > ranges[usingRange].sqrtPriceTop : sqrtPriceLimit < ranges[usingRange].sqrtPriceBottom
				|| sqrtPriceLimit == 0)
			){
                amountRecieved += _swapInRange( usingRange, s.to, s.zeroForOne, usingReserve);
				remained -= usingReserve;
                usingRange = inUseRange;
                usingReserve = s.zeroForOne ? ranges[usingRange].reserve1 : ranges[usingRange].reserve0;
            }
            amountRecieved += _swapInRange( usingRange, s.to, s.zeroForOne, remained);
			amountSend = uint256(-s.amount) - remained; 
        } 
        //
        //  exactTokensForTokens
        //
        else {
            remained = uint256(s.amount);
            uint256 predictedFee = remained *feePercentage/D;
            (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(usingRange);
            uint256 amountOut = PoolHelper.AmountOut(s.zeroForOne, h.value00, h.value01, h.value10, h.value11, remained-predictedFee);
            while(amountOut >= (s.zeroForOne? h.value01 : h.value00) &&
				(s.zeroForOne ? sqrtPriceLimit > ranges[usingRange].sqrtPriceTop : sqrtPriceLimit < ranges[usingRange].sqrtPriceBottom
				|| sqrtPriceLimit == 0)
			) {
                remained -= _swapInRange(usingRange, s.to, s.zeroForOne, h.value00);
                amountSend += s.zeroForOne ? h.value01 : h.value00;
                predictedFee = remained *feePercentage/D;
				usingRange = inUseRange;
                (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(usingRange); 
                amountOut = PoolHelper.AmountIn(s.zeroForOne, h.value00, h.value01, h.value10, h.value11, remained-predictedFee);
            }
            remained -= _swapInRange(usingRange, s.to, s.zeroForOne, amountOut);
            amountSend += amountOut;
			amountRecieved = uint256(s.amount) - remained;
        }
		//!!!
		TransferHelper.safeTransfer(s.zeroForOne ? token1 : token0, s.to, amountSend);
		IDesireSwapV0SwapCallback(msg.sender).desireSwapV0SwapCallback(
			s.zeroForOne ? int256(amountRecieved) : -int256(amountSend),
			s.zeroForOne ? -int256(amountSend) : int256(amountRecieved),
			data
		);
		h.balance0 = balance0();
        h.balance1 = balance1();
        //???
		if( s.zeroForOne){
			require( h.balance0 >= h.lastBalance0 + amountRecieved && h.balance1 >= h.lastBalance1 - amountSend,
	            'DesireSwapV0: BALANCES_ARE_T0O_LOW');
        } else {
            require( h.balance1 >= h.lastBalance1 + amountRecieved && h.balance0 >= h.lastBalance0 - amountSend,
                    'DesireSwapV0: BALANCES_ARE_T0O_LOW');
        }	

        int256 amount0 = int256(h.balance0) - int256(h.lastBalance0);
		int256 amount1 = int256(h.balance1) - int256(h.lastBalance1);
		_updateLastBalances(h.balance0, h.balance1);
        emit Swap( msg.sender, s.zeroForOne, s.amount, s.to);
		delete h;
		return (amount0, amount1);
    }
///
///	ADD LIQUIDITY
///

	//  The proof of being LP is Ticket that stores information of how much liquidity was provided.
	//  It is minted when L is provided.
	//  It is burned when L is taken.

	function _printOnTicket0(
		int24 index,
		uint256 ticketId,
		uint256 liqToAdd) 
	private
	returns(uint256 amount0ToAdd)
	{ 
		if(!ranges[index].activated) activate(index);
		uint256 reserve0 = ranges[index].reserve0;
		uint256 reserve1 = ranges[index].reserve1;
		uint256 sqrtPriceBottom = ranges[index].sqrtPriceBottom;
		uint256 sqrtPriceTop = ranges[index].sqrtPriceTop;
		
		amount0ToAdd = reserve0*sqrtRangeMultiplier*sqrtPriceBottom/(sqrtRangeMultiplier -D)/D; 
		
		if(ranges[index].supplyCoefficient != 0){
			_ticketSupplyData[ticketId][index] = ranges[index].supplyCoefficient*amount0ToAdd/reserve0;
		}
		else{
			_ticketSupplyData[ticketId][index] = 
				PoolHelper.LiqCoefficient(
					reserve0, reserve1,
        			sqrtPriceBottom, sqrtPriceTop
				)/D;
		}
		ranges[index].supplyCoefficient += _ticketSupplyData[ticketId][index];
		//!!
		_modifyRangeReserves(index, liqToAdd, 0, true, true); 
	}
	function _printOnTicket1(
		int24 index,
		uint256 ticketId,
		uint256 liqToAdd)
	private
	returns(uint256 amount1ToAdd)
	{ 
		if(!ranges[index].activated) activate(index);
		uint256 reserve0 = ranges[index].reserve0;
		uint256 reserve1 = ranges[index].reserve1;
		uint256 sqrtPriceBottom = ranges[index].sqrtPriceBottom;
		uint256 sqrtPriceTop = ranges[index].sqrtPriceTop;

		amount1ToAdd = liqToAdd * (sqrtPriceTop - sqrtPriceBottom)/D;

		if(ranges[index].supplyCoefficient != 0){
			_ticketSupplyData[ticketId][index] = ranges[index].supplyCoefficient*amount1ToAdd/reserve1;
		}
		else{
			_ticketSupplyData[ticketId][index] = 
			PoolHelper.LiqCoefficient(
				reserve0, reserve1,
        		sqrtPriceBottom, sqrtPriceTop
			)/D;
		}
		ranges[index].supplyCoefficient += _ticketSupplyData[ticketId][index];
		//!!
		_modifyRangeReserves(index, 0, amount1ToAdd, true, true); 
	}
		
	function mint(
        address to,
        int24 lowestRangeIndex,
        int24 highestRangeIndex,
        uint256 liqToAdd,
		bytes calldata data)
    external override
    returns(uint256 amount0, uint256 amount1)
    {
		require(msg.sender == IDesireSwapV0Factory(factory).owner());
        require(highestRangeIndex >= lowestRangeIndex);
		helpData memory h = helpData({
			lastBalance0: lastBalance0, lastBalance1: lastBalance1,
			balance0: balance0(), balance1: balance1(),
			value00: 0, value01: 0,
			value10: 0, value11: 0});
		uint256 ticketId = _mint(to);
        int24 usingRange = inUseRange;   
		_ticketData[ticketId].lowestRangeIndex = lowestRangeIndex;
		_ticketData[ticketId].highestRangeIndex = highestRangeIndex;
		_ticketData[ticketId].liqAdded = liqToAdd;

        if(highestRangeIndex < usingRange){
			//in this case ranges.reserve1 should be 0
            for(int24 i = highestRangeIndex; i >= lowestRangeIndex; i--){
                amount0 += _printOnTicket0(i, ticketId, liqToAdd);                
            }
        }
		else if(lowestRangeIndex > usingRange)
        {
            // in this case ranges.reserve0 should be 0
            for(int24 i = lowestRangeIndex; i <= highestRangeIndex; i++){
                amount1 +=  _printOnTicket1(i, ticketId, liqToAdd);
            }   
        }
		else
        {
            for(int24 i = usingRange - 1; i >= lowestRangeIndex; i--){
                amount0 += _printOnTicket0(i, ticketId, liqToAdd);               
            }
			
			for(int24 i = usingRange + 1; i >= highestRangeIndex; i++){
				amount1 +=  _printOnTicket1(i, ticketId, liqToAdd); 
            }


            if(!ranges[usingRange].activated) activate(usingRange);
            (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(usingRange);
			uint256 LiqCoefBefore = PoolHelper.LiqCoefficient(h.value00, h.value01, h.value10, h.value11); 
            uint256 amount0ToAdd;
			uint256 amount1ToAdd;
			if(h.value00 == 0 && h.value01 == 0){
				amount0ToAdd = liqToAdd * (h.value10*h.value11/(h.value11-h.value10))/2;
				amount1ToAdd = liqToAdd * (h.value11 - h.value10)/D/2;
			}
			else{
				amount0ToAdd = liqToAdd/LiqCoefBefore* h.value00;
            	amount1ToAdd = liqToAdd/LiqCoefBefore* h.value01;
			}
			uint256 LiqCoefAfter = PoolHelper.LiqCoefficient(h.value00 + amount0ToAdd, h.value01 + amount1ToAdd, h.value10, h.value11);
			require(LiqCoefAfter >= LiqCoefBefore + liqToAdd, "DesireSwapV0: LIQ_ERROR");

			amount0 += amount0ToAdd;
			amount1 += amount1ToAdd;

            if(ranges[usingRange].supplyCoefficient != 0){
				_ticketSupplyData[ticketId][usingRange] = ranges[usingRange].supplyCoefficient * (LiqCoefAfter - LiqCoefBefore)/LiqCoefBefore;             
            } else 
            {
                _ticketSupplyData[ticketId][usingRange] = LiqCoefAfter/D;                
            }
            //!!
			ranges[usingRange].supplyCoefficient += _ticketSupplyData[ticketId][usingRange];
			//!!
            _modifyRangeReserves(usingRange, amount0ToAdd, amount1ToAdd, true ,true); 
        }
		IDesireSwapV0MintCallback(msg.sender).desireSwapV0MintCallback(amount0, amount1, data);
		///???
		require(h.balance0 >= h.lastBalance0 + amount0 && h.balance1 >= h.lastBalance1 + amount1, 'DesireSwapV0: BALANCES_ARE_TOO_LOW');
	    emit Mint(to, ticketId);
        _updateLastBalances(h.balance0, h.balance1);
		delete h;
    }

///
///	REDEEM LIQ
///
	// zeroOrOne 0=false if only token0 in reserves, 1=true if only token 1 in reserves.
	function _readTicket(
		int24 index,
		uint256 ticketId,
		bool zeroOrOne)
	private
	returns(uint256 amountToTransfer)
	{
		uint256 supply = _ticketSupplyData[ticketId][index];
		_ticketSupplyData[ticketId][index] = 0;
		if(zeroOrOne){
			amountToTransfer = supply*ranges[index].reserve0/ranges[index].supplyCoefficient;
			//!!
			_modifyRangeReserves(index, amountToTransfer, 0, false, false);
		} else {
			amountToTransfer = supply*ranges[index].reserve1/ranges[index].supplyCoefficient;
			//!!
			_modifyRangeReserves(index, 0, amountToTransfer, false, false);			
		}
		//!!
		ranges[index].supplyCoefficient -= supply;
	}

	function burn(
		address to,
		uint256 ticketId)
	external override
	returns (uint256, uint256)
	{
		require(_exists(ticketId), 'DesireSwapV0: TOKEN_DOES_NOT_EXISTS');
		address owner = Ticket.ownerOf(ticketId);
		require(tx.origin == owner,'DesireSwapV0: SENDER_IS_NOT_THE_OWNER');
		_burn(ticketId);

		helpData memory h;
		h.lastBalance0 = lastBalance0;
		h.lastBalance1 = lastBalance1;
		int24 usingRange = inUseRange;
			
		int24 highestRangeIndex = _ticketData[ticketId].highestRangeIndex;
		int24 lowestRangeIndex = _ticketData[ticketId].lowestRangeIndex;
		if(highestRangeIndex < usingRange){
			for(int24 i = highestRangeIndex; i >= highestRangeIndex; i--){
				h.value00 += _readTicket(i, ticketId, false);
			}
		} else if(lowestRangeIndex > usingRange){
			for(int24 i = lowestRangeIndex; i <= highestRangeIndex; i++){
				h.value01 += _readTicket(i, ticketId, true);
			}
		} else
		{
			for(int24 i = highestRangeIndex; i > usingRange; i--){
				h.value00 += _readTicket(i, ticketId, false);
			}
			for(int24 i = lowestRangeIndex; i < usingRange; i++){
				h.value01 += _readTicket(i, ticketId, true);
			}
				
			uint256 supply = _ticketSupplyData[ticketId][usingRange];
			_ticketSupplyData[ticketId][usingRange] = 0;
			h.value10 = supply*ranges[usingRange].reserve0/ranges[usingRange].supplyCoefficient;
			h.value11 = supply*ranges[usingRange].reserve1/ranges[usingRange].supplyCoefficient;
			h.value00 += h.value10;
			h.value01 += h.value11;
			_modifyRangeReserves(usingRange, h.value10, h.value11, false, false);
			ranges[usingRange].supplyCoefficient -= supply;
		}
		//!!!
		TransferHelper.safeTransfer(token0, to, h.value00);
		TransferHelper.safeTransfer(token1, to, h.value01);
		h.balance0 = balance0();
		h.balance1 = balance1();
		//???
		require(h.balance0 >= h.lastBalance0 - h.value00 && h.balance1 >= h.lastBalance1 - h.value01, 'DesireSwapV0: BALANCES_ARE_TO0_LOW');
		emit Burn(owner, ticketId);
		//!!!
		_updateLastBalances(h.balance0, h.balance1);
		uint256 amount0 = h.value00;
		uint256 amount1 = h.value01;
		delete h;
		return (amount0, amount1);
	}

	//
	// FLASH
	//
	function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data)
	external override
	{
        uint256 fee0 = amount0*feePercentage/D;
        uint256 fee1 = amount1*feePercentage/D;
        uint256 balance0Before = balance0();
        uint256 balance1Before = balance1();

        if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);

        IDesireSwapV0FlashCallback(msg.sender).desireSwapV0FlashCallback(fee0, fee1, data);

        uint256 balance0After = balance0();
        uint256 balance1After = balance1();

        require(balance0Before + fee0 <= balance0After, 'F0');
        require(balance1Before + fee1 <= balance1After, 'F1');

		uint256 paid0 = balance0After - balance0Before;
		uint256 paid1 = balance1After - balance1Before;

        emit Flash(msg.sender, recipient, amount0, amount1, paid0, paid1);
    }

	
///
/// OWNER ACTIONS
///

	function initialize(uint256 _startingSqrtPriceBottom)
	external override 
	{
		require(msg.sender == IDesireSwapV0Factory(factory).owner());
		require(initialized == false, "DesireSwapV0Pool: IS_ALREADY_INITIALIZED");
		ranges[0].sqrtPriceBottom = _startingSqrtPriceBottom;
		ranges[0].sqrtPriceTop = _startingSqrtPriceBottom*sqrtRangeMultiplier/10**18;
		ranges[0].activated = true;
		initialized = true;
	}
	
	function collectFee(
		address token,
		uint256 amount)
	external override 
	{
		require(msg.sender == IDesireSwapV0Factory(factory).owner());
		TransferHelper.safeTransfer(token, IDesireSwapV0Factory(factory).feeCollector(), amount);
		require( IERC20(token0).balanceOf(address(this)) >= totalReserve0
			  && IERC20(token1).balanceOf(address(this)) >= totalReserve1);
		emit CollectFee(token, amount);
	}

	function setProtocolFee(bool _protocolFeeIsOn, uint256 _protocolFeePart)
	external override
	{
		require(msg.sender == IDesireSwapV0Factory(factory).owner());
	}
}
