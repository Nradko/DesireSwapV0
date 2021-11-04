/************************************************************************************************
 * Copyright (C) 2021-2022  <desired.desire@protonmail.com>
 *
 * "Author" should be understood at person who is using email: <desired.desire@protonmail.com>
 *
 * This file is part of DesireSwap protocol and was developed by Author .
 *
 * DesireSwap protocol files that are said to be developed by Author can not be copied
 * and/or distributed without the express permission of Author.
 *
 * Author gives permission to everyone to copy and use these files only in order to test them.
 ************************************************************************************************/

pragma solidity ^0.8.0;
pragma abicoder v2;

import './base/Ticket.sol';

import './interfaces/callback/IDesireSwapV0MintCallback.sol';
import './interfaces/callback/IDesireSwapV0SwapCallback.sol';
import './interfaces/callback/IDesireSwapV0FlashCallback.sol';
import './interfaces/IDesireSwapV0Factory.sol';
import './interfaces/IDesireSwapV0Pool.sol';

import './libraries/PoolHelper.sol';
import './libraries/TransferHelper.sol';

contract DesireSwapV0Pool is Ticket, IDesireSwapV0Pool {
  bool public override initialized;
  bool public override protocolFeeIsOn = true;

  address public immutable override factory;
  address public immutable override token0;
  address public immutable override token1;
  address public override swapRouter;

  uint256 private constant E18 = 10**18;
  uint256 private constant E6 = 10**6;
  uint256 private constant TICK_SIZE = 1000049998750062496;
  uint256 private immutable ticksInRange;
  uint256 public immutable override sqrtRangeMultiplier; // example: 100100000.... is 1.001 (* 10**)
  uint256 public immutable sqrtRangeMultiplier100; // sqrtRangeMultipier**100
  uint256 public immutable override fee; //  0 fee is 0 // 100% fee is 1* 10**6;
  uint256 public override protocolFeePart = 200000;
  uint256 private totalReserve0;
  uint256 private totalReserve1;
  uint256 private lastBalance0;
  uint256 private lastBalance1;

  struct Range {
    uint256 reserve0;
    uint256 reserve1;
    uint256 sqrtPriceBottom; //  sqrt(lower position bound price) * 10**18 // price of token0 in token1 for 1 token0 i get priceBottom of tokens1
    uint256 supplyCoefficient;
    bool activated;
  }

  mapping(int24 => Range) public ranges;

  int24 public override inUseRange;
  int24 public override highestActivatedRange;
  int24 public override lowestActivatedRange;

  constructor(
    address factory_,
    address swapRouter_,
    address token0_,
    address token1_,
    uint256 fee_,
    uint256 ticksInRange_,
    uint256 sqrtRangeMultiplier_,
    uint256 sqrtRangeMultiplier100_,
    string memory name_,
    string memory symbol_
  ) Ticket(name_, symbol_) {
    initialized = false;
    factory = factory_;
    swapRouter = swapRouter_;
    token0 = token0_;
    token1 = token1_;
    fee = fee_;
    ticksInRange = ticksInRange_;
    sqrtRangeMultiplier = sqrtRangeMultiplier_;
    sqrtRangeMultiplier100 = sqrtRangeMultiplier100_;
  }

  ///
  /// VIEW
  ///
  /// inherit doc from IDesreSwapV0Pool
  function balance0() public view override returns (uint256) {
    return IERC20(token0).balanceOf(address(this));
  }

  /// inherit doc from IDesreSwapV0Pool
  function balance1() public view override returns (uint256) {
    return IERC20(token1).balanceOf(address(this));
  }

  /// inherit doc from IDesreSwapV0Pool
  function getLastBalances() external view override returns (uint256 _lastBalance0, uint256 _lastBalance1) {
    _lastBalance0 = lastBalance0;
    _lastBalance1 = lastBalance1;
  }

  /// inherit doc from IDesreSwapV0Pool
  function getTotalReserves() external view override returns (uint256 _totalReserve0, uint256 _totalReserve1) {
    _totalReserve0 = totalReserve0;
    _totalReserve1 = totalReserve1;
  }

  /// note returns data of range with index = index
  function getRangeInfo(int24 index)
    private
    view
    returns (
      uint256 _reserve0,
      uint256 _reserve1,
      uint256 _sqrtPriceBottom,
      uint256 _sqrtPriceTop
    )
  {
    _reserve0 = ranges[index].reserve0;
    _reserve1 = ranges[index].reserve1;
    _sqrtPriceBottom = ranges[index].sqrtPriceBottom;
    _sqrtPriceTop = (_sqrtPriceBottom * sqrtRangeMultiplier) / E18;
  }

  /// inherit doc from IDesreSwapV0Pool
  function getFullRangeInfo(int24 index)
    external
    view
    override
    returns (
      uint256 _reserve0,
      uint256 _reserve1,
      uint256 _sqrtPriceBottom,
      uint256 _sqrtPriceTop,
      uint256 _supplyCoefficient,
      bool _activated
    )
  {
    _reserve0 = ranges[index].reserve0;
    _reserve1 = ranges[index].reserve1;
    _sqrtPriceBottom = ranges[index].sqrtPriceBottom;
    _sqrtPriceTop = (_sqrtPriceBottom * sqrtRangeMultiplier) / E18;
    _supplyCoefficient = ranges[index].supplyCoefficient;
    _activated = ranges[index].activated;
  }

  /// inherit doc from IDesreSwapV0Pool
  function inUseInfo()
    public
    view
    override
    returns (
      int24 usingRange,
      uint256 sqrtCurrentPrice,
      uint256 inUseLiq,
      uint256 inUseReserve0,
      uint256 inUseReserve1
    )
  {
    usingRange = inUseRange * int24(int256(ticksInRange));
    (uint256 reserve0, uint256 reserve1, uint256 sqrt0, uint256 sqrt1) = getRangeInfo(usingRange);
    inUseLiq = PoolHelper.liqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
    sqrtCurrentPrice = (inUseLiq * E18) / (reserve0 + (inUseLiq * E18) / sqrt1);
    inUseReserve0 = reserve0;
    inUseReserve1 = reserve1;
  }

  ///
  /// private
  ///
  /// note updates lastBalances
  function _updateLastBalances(uint256 _lastBalance0, uint256 _lastBalance1) private {
    lastBalance0 = _lastBalance0;
    lastBalance1 = _lastBalance1;
  }

  /// note modifyRangeReserves and changes the inUsePosition if reserves are used
  function _updateRangeReserves(
    int24 index,
    uint256 toAdd0,
    uint256 toAdd1,
    bool add0, /// add or substract
    bool add1,
    bool isSwap
  ) private {
    uint256 updatedReserve0 = add0 ? ranges[index].reserve0 + toAdd0 : ranges[index].reserve0 - toAdd0;
    uint256 updatedReserve1 = add1 ? ranges[index].reserve1 + toAdd1 : ranges[index].reserve1 - toAdd1;
    ranges[index].reserve0 = updatedReserve0;
    ranges[index].reserve1 = updatedReserve1;
    totalReserve0 = add0 ? totalReserve0 + toAdd0 : totalReserve0 - toAdd0;
    totalReserve1 = add1 ? totalReserve1 + toAdd1 : totalReserve1 - toAdd1;

    if (isSwap) {
      if (updatedReserve0 == 0 && ranges[inUseRange+1].activated && index == inUseRange) {
        inUseRange++;
        emit InUseRangeChanged(index, index + 1);
      }
      if (updatedReserve1 == 0 && ranges[inUseRange-1].activated && index == inUseRange) {
        inUseRange--;
        emit InUseRangeChanged(index, index - 1);
      }
    }
  }

  /// note activates the ranges up/down to range with index = index
  function activate(int24 index) public override {
    require(!ranges[index].activated, 'Pa');
    if (index > highestActivatedRange) {
      for (int24 i = highestActivatedRange + 1; i <= index; i++) {
        ranges[i].sqrtPriceBottom = (ranges[i - 1].sqrtPriceBottom * sqrtRangeMultiplier) / E18;
        ranges[i].activated = true;
      }
      highestActivatedRange = index;
    } else if (index < lowestActivatedRange) {
      for (int24 i = lowestActivatedRange - 1; i >= index; i--) {
        ranges[i].sqrtPriceBottom = (ranges[i + 1].sqrtPriceBottom * E18) / sqrtRangeMultiplier;
        ranges[i].activated = true;
      }
      lowestActivatedRange = index;
    }
  }

  ///
  /// POOL ACTIONS
  ///


  struct HelpData {
    uint256 lastBalance0;
    uint256 lastBalance1;
    uint256 balance0;
    uint256 balance1;
    uint256 value00;
    uint256 value01;
    uint256 value10;
    uint256 value11;
  }

  /// @notice this method is used to perfom swaps. it changes data of range by amountOut and amountIn
  /// @param index of range which data will be modified
  /// @param zeroForOne swapping token0 for token1 (true) ot token1 for token0 (false)
  /// @param amountOut amountOut of token that goes out of pool that should be transferred out
  /// @param amountIn retuns amountIn of token that enters the pool that should be transfered in
  function _swapInRange(
    int24 index,
    bool zeroForOne,
    uint256 amountOut
  ) private returns (uint256 amountIn) {
    require(index == inUseRange, 'PsIR0');
    HelpData memory h = HelpData({lastBalance0: lastBalance0, lastBalance1: lastBalance1, balance0: 0, balance1: 0, value00: 0, value01: 0, value10: 0, value11: 0});

    (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(index);  // reserve0, reserve1, sqrtPriceBot, sqrtPriceTop
    require((zeroForOne && amountOut <= h.value01) || (!zeroForOne && amountOut <= h.value00), 'PsIR1');
    uint256 amountInHelp = PoolHelper.AmountIn(zeroForOne, h.value00, h.value01, h.value10, h.value11, amountOut); // do not include fees;
    uint256 collectedFee = (amountInHelp * fee) / E6;
    amountIn = amountInHelp + collectedFee;
    amountInHelp = amountIn;
    if (protocolFeeIsOn) {
      amountInHelp = amountIn - (collectedFee * protocolFeePart) / E6; //amountIn - protocolFee. It is amount that is added to reserve
    }
    if (zeroForOne) {
      //??
      require(
        PoolHelper.liqCoefficient(h.value00 + amountInHelp, h.value01 - amountOut, h.value10, h.value11) >= PoolHelper.liqCoefficient(h.value00, h.value01, h.value10, h.value11),
        'PsIR2'
      ); //assure that after swap there is more or equal liquidity. If PoolHelper.AmountIn works correctly it can be removed.
      //!!
      require(amountOut <= h.value01, 'PsIR2');
      _updateRangeReserves(index, amountInHelp, amountOut, true, false, true);
    }
    // token1 for token0 // token1 in; token0 out;
    else {
      //??
      require(
        PoolHelper.liqCoefficient(h.value00 - amountOut, h.value01 + amountInHelp, h.value10, h.value11) >= PoolHelper.liqCoefficient(h.value00, h.value01, h.value10, h.value11),
        'PsIR3'
      ); //assure that after swap there is more or equal liquidity. If PoolHelper.AmountIn works correctly it can be removed.
      //!!
      require(amountOut <= h.value00, 'PsIR4');
      _updateRangeReserves(index, amountOut, amountInHelp, false, true, true);
    }
    delete h;
  }

  // This function uses swapInRange to make any swap.
  // The calldata is not yet used. SwapRoutes!!!!!!!
  // amount > 0 amount is exact token inflow, amount < 0 amount is exact token outflow.
  // sqrtPriceLimit is price

  struct SwapParams {
    address to;
    bool zeroForOne;
    int256 amount;
    bytes data;
  }

/// inherit doc from IDesreSwapV0Pool
  function swap(
    address to,
    bool zeroForOne,
    int256 amount,
    bytes calldata data
  ) external override returns (int256, int256) {
    if (msg.sender != swapRouter) require(IDesireSwapV0Factory(factory).allowlisted(msg.sender), 'Ps0');
    SwapParams memory s = SwapParams({to: to, zeroForOne: zeroForOne, amount: amount, data: data});
    HelpData memory h = HelpData({lastBalance0: lastBalance0, lastBalance1: lastBalance1, balance0: 0, balance1: 0, value00: 0, value01: 0, value10: 0, value11: 0});
    uint256 usingReserve;
    uint256 amountRecieved;
    uint256 amountSend;
    uint256 remained;
    int24 usingRange = inUseRange;
    //
    // tokensForExactTokens
    //
    // token0 In, token1 Out, tokensForExactTokens
    if (s.amount < 0) {
      remained = uint256(-s.amount);
      if (s.zeroForOne) {
        require(remained <= totalReserve1, 'Ps1');
        usingReserve = ranges[usingRange].reserve1;
      } else {
        require(remained <= totalReserve0, 'Ps02');
        usingReserve = ranges[usingRange].reserve0;
      }
      while (remained > usingReserve) {
        amountRecieved += _swapInRange(usingRange, s.zeroForOne, usingReserve);
        remained -= usingReserve;
        usingRange = inUseRange;
        usingReserve = s.zeroForOne ? ranges[usingRange].reserve1 : ranges[usingRange].reserve0;
      }
      if(remained > 0) amountRecieved += _swapInRange(usingRange, s.zeroForOne, remained);
      amountSend = uint256(-s.amount);
    }
    //
    //  exactTokensForTokens
    //
    else if (s.amount > 0) {
      remained = uint256(s.amount);
      uint256 predictedFee = (remained * fee) / E6;
      (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(usingRange);
      uint256 amountOut = PoolHelper.AmountOut(s.zeroForOne, h.value00, h.value01, h.value10, h.value11, remained - predictedFee);
      usingReserve = s.zeroForOne ? h.value01 : h.value00;
      while (amountOut > usingReserve) {
        remained -= _swapInRange(usingRange, s.zeroForOne, s.zeroForOne ? h.value01 : h.value00);
        amountSend += s.zeroForOne ? h.value01 : h.value00;
        predictedFee = (remained * fee) / E6;
        usingRange = inUseRange;
        (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(usingRange);
        usingReserve = s.zeroForOne ? h.value01 : h.value00;
        amountOut = PoolHelper.AmountOut(s.zeroForOne, h.value00, h.value01, h.value10, h.value11, remained - predictedFee);
      }
      
      uint256 help = _swapInRange(usingRange, s.zeroForOne, amountOut);
      require(help <= remained, 'Ps3');
      remained -= help;
      amountSend += amountOut;
      amountRecieved = uint256(s.amount) - remained;
      }
    //!!!
    TransferHelper.safeTransfer(s.zeroForOne ? token1 : token0, s.to, amountSend);
    IDesireSwapV0SwapCallback(msg.sender).desireSwapV0SwapCallback(s.zeroForOne ? int256(amountRecieved) : -int256(amountSend), s.zeroForOne ? -int256(amountSend) : int256(amountRecieved), data);
    h.balance0 = balance0();
    h.balance1 = balance1();
    //???
    if (s.zeroForOne) {
      require(h.balance0 >= h.lastBalance0 + amountRecieved && h.balance1 >= h.lastBalance1 - amountSend, 'Ps4');
    } else {
      require(h.balance1 >= h.lastBalance1 + amountRecieved && h.balance0 >= h.lastBalance0 - amountSend, 'Ps5');
    }
    _updateLastBalances(h.balance0, h.balance1);
    delete h;
    if (s.zeroForOne) {
      emit Swap(msg.sender, s.to, block.number, int256(amountRecieved), -int256(amountSend));
      delete s;
      return (int256(amountRecieved), -int256(amountSend));
    }
    delete s;
    emit Swap(msg.sender, s.to, block.number, -int256(amountSend), int256(amountRecieved));
    return (-int256(amountSend), int256(amountRecieved));
  }

  ///
  ///	ADD LIQUIDITY
  ///

  /// @notice this method  is writing data down on ticket while performing mint
  function _printOnTicket0(
    int24 index,
    uint256 ticketId,
    uint256 liqToAdd
  ) private returns (uint256 amount0ToAdd) {
    if (!ranges[index].activated) activate(index);
    (
      uint256 reserve0, 
      /*unused*/,
      uint256 sqrtPriceBottom,
      uint256 sqrtPriceTop
    ) = getRangeInfo(index);
    if(sqrtPriceBottom < E18){
      amount0ToAdd = liqToAdd * E18 * (sqrtPriceTop - sqrtPriceBottom) / (sqrtPriceBottom * sqrtPriceTop);
    }else{
      amount0ToAdd = liqToAdd * (sqrtPriceTop - sqrtPriceBottom) / (sqrtPriceBottom * sqrtPriceTop / E18);
    }
    uint256 supplyData;
    if (ranges[index].supplyCoefficient != 0) {
      supplyData = (ranges[index].supplyCoefficient * amount0ToAdd) / reserve0;
    } else {
      supplyData = PoolHelper.liqCoefficient(amount0ToAdd, 0, sqrtPriceBottom, sqrtPriceTop);
    }
    _ticketSupplyData[ticketId][index] = supplyData;
    ranges[index].supplyCoefficient += supplyData;
    //!!
    _updateRangeReserves(index, amount0ToAdd, 0, true, true, false);
  }

  /// @notice this method  is writing data down on ticket while performing mint
  function _printOnTicket1(
    int24 index,
    uint256 ticketId,
    uint256 liqToAdd
  ) private returns (uint256 amount1ToAdd) {
    if (!ranges[index].activated) activate(index);
    (
      /*unused*/,
      uint256 reserve1,
      uint256 sqrtPriceBottom,
      uint256 sqrtPriceTop
    ) = getRangeInfo(index);

    amount1ToAdd = (liqToAdd * (sqrtPriceTop - sqrtPriceBottom)) / E18;
    uint256 supplyData;
    if (ranges[index].supplyCoefficient != 0) {
      supplyData = (ranges[index].supplyCoefficient * amount1ToAdd) / reserve1;
    } else {
      supplyData = PoolHelper.liqCoefficient(0, amount1ToAdd, sqrtPriceBottom, sqrtPriceTop);
    }
    _ticketSupplyData[ticketId][index] = supplyData;
    ranges[index].supplyCoefficient += supplyData;
    //!!
    _updateRangeReserves(index, 0, amount1ToAdd, true, true, false);
  }

  /// inherit doc from IDesreSwapV0Pool
  function mint(
    address to,
    int24 lowestRangeIndex,
    int24 highestRangeIndex,
    uint256 liqToAdd,
    bytes calldata data
  )
    external
    override
    returns (
      uint256 ticketId,
      uint256 amount0,
      uint256 amount1
    )
  {

    require(initialized, 'Pm0');
    require(highestRangeIndex >= lowestRangeIndex, 'Pm1');
    HelpData memory h = HelpData({lastBalance0: lastBalance0, lastBalance1: lastBalance1, balance0: 0, balance1: 0, value00: 0, value01: 0, value10: 0, value11: 0});
    ticketId = _nextTicketId++;
    _safeMint(to, ticketId);
    int24 usingRange = inUseRange;
    _ticketData[ticketId].lowestRangeIndex = lowestRangeIndex;
    _ticketData[ticketId].highestRangeIndex = highestRangeIndex;
    _ticketData[ticketId].liqAdded = liqToAdd;
    if (lowestRangeIndex > usingRange) //in this case ranges.reserve1 should be 0
    {
      for (int24 i = highestRangeIndex; i >= lowestRangeIndex; i--) {
        amount0 += _printOnTicket0(i, ticketId, liqToAdd);
      }
    } else if (highestRangeIndex < usingRange) // in this case ranges.reserve0 should be 0
    {
      for (int24 i = lowestRangeIndex; i <= highestRangeIndex; i++) {
        amount1 += _printOnTicket1(i, ticketId, liqToAdd);
      }
    } else {
      for (int24 i = usingRange + 1; i <= highestRangeIndex; i++) {
        amount0 += _printOnTicket0(i, ticketId, liqToAdd);
      }

      for (int24 i = usingRange - 1; i >= lowestRangeIndex; i--) {
        amount1 += _printOnTicket1(i, ticketId, liqToAdd);
      }
      (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(usingRange);  // reserve0, reserve1, sqrtPriceBot, sqrtPriceTop
      uint256 liqCoefBefore = PoolHelper.liqCoefficient(h.value00, h.value01, h.value10, h.value11);
      uint256 amount0ToAdd;
      uint256 amount1ToAdd;
      if ( (h.value00 == 0 && h.value01 == 0 ) || liqCoefBefore == 0) {
        amount0ToAdd = (liqToAdd * E18 * (h.value11 - h.value10)) / (h.value10 * h.value11) / 2;
        amount1ToAdd = (liqToAdd * (h.value11 - h.value10)) / E18 / 2;
      } else {
        amount0ToAdd = (liqToAdd * h.value00) / liqCoefBefore;
        amount1ToAdd = (liqToAdd * h.value01) / liqCoefBefore;
      }
      uint256 liqCoefAfter = PoolHelper.liqCoefficient(h.value00 + amount0ToAdd, h.value01 + amount1ToAdd, h.value10, h.value11);
      // require(liqCoefAfter >= liqCoefBefore + liqToAdd, "DesireSwapV0: LIQ_ERROR");
      amount0 += amount0ToAdd;
      amount1 += amount1ToAdd;
      if (ranges[usingRange].supplyCoefficient != 0 && liqCoefBefore != 0) {
        _ticketSupplyData[ticketId][usingRange] = (ranges[usingRange].supplyCoefficient * (liqCoefAfter - liqCoefBefore)) / liqCoefBefore;
      } else {
        _ticketSupplyData[ticketId][usingRange] = liqCoefAfter;
      }
      //!!
      ranges[usingRange].supplyCoefficient += _ticketSupplyData[ticketId][usingRange];
      //!!
      _updateRangeReserves(usingRange, amount0ToAdd, amount1ToAdd, true, true, false);
    }
    IDesireSwapV0MintCallback(msg.sender).desireSwapV0MintCallback(amount0, amount1, data);
    ///???
    h.balance0 = balance0();
    h.balance1 = balance1();
    require(h.balance0 >= h.lastBalance0 + amount0 && h.balance1 >= h.lastBalance1 + amount1, 'Pm2');
    emit Mint(msg.sender, to, lowestRangeIndex, highestRangeIndex, ticketId, liqToAdd, amount0, amount1);
    _updateLastBalances(h.balance0, h.balance1);
    delete h;
  }

  ///
  ///	REDEEM LIQ
  ///
  
  /// @notice method that reads from ticket data used for ranges out of current Price
  /// @param index of range that we are reading from
  /// @param ticketId Id of ticket that is beeing burned
  /// @param sendZero if only token 0 should be send (true) or only token1 (false)
  /// @return amountToTransfer amount that should be transfer out of pool.
  function _readTicket(
    int24 index,
    uint256 ticketId,
    bool sendZero
  ) private returns (uint256 amountToTransfer) {
    uint256 supply = _ticketSupplyData[ticketId][index];
    _ticketSupplyData[ticketId][index] = 0;
    if (sendZero) {
      amountToTransfer = (supply * ranges[index].reserve0) / ranges[index].supplyCoefficient;
      //!!
      _updateRangeReserves(index, amountToTransfer, 0, false, false, false);
    } else {
      amountToTransfer = (supply * ranges[index].reserve1) / ranges[index].supplyCoefficient;
      //!!
      _updateRangeReserves(index, 0, amountToTransfer, false, false, false);
    }
    //!!
    ranges[index].supplyCoefficient -= supply;
  }

  /// inherit doc from IDesreSwapV0Pool
  function burn(address to, uint256 ticketId) external override returns (uint256, uint256) {
    require(_exists(ticketId), 'Pb0');
    if(!(msg.sender == ownerOf(ticketId))){
      require(_isApprovedOrOwner(_msgSender(), ticketId), 'Pb1');
      require(tx.origin == ownerOf(ticketId));
    }
    HelpData memory h = HelpData({lastBalance0: lastBalance0, lastBalance1: lastBalance1, balance0: 0, balance1: 0, value00: 0, value01: 0, value10: 0, value11: 0});
    int24 usingRange = inUseRange;

    int24 highestRangeIndex = _ticketData[ticketId].highestRangeIndex;
    int24 lowestRangeIndex = _ticketData[ticketId].lowestRangeIndex;
    if (highestRangeIndex < usingRange) {
      for (int24 i = highestRangeIndex; i >= lowestRangeIndex; i--) {
        h.value00 += _readTicket(i, ticketId, true);
      }
    } else if (lowestRangeIndex > usingRange) {
      for (int24 i = lowestRangeIndex; i <= highestRangeIndex; i++) {
        h.value01 += _readTicket(i, ticketId, false);
      }
    } else {
      for (int24 i = highestRangeIndex; i > usingRange; i--) {
        h.value00 += _readTicket(i, ticketId, true);
      }
      for (int24 i = lowestRangeIndex; i < usingRange; i++) {
        h.value01 += _readTicket(i, ticketId, false);
      }
      uint256 supply = _ticketSupplyData[ticketId][usingRange];
      _ticketSupplyData[ticketId][usingRange] = 0;
      h.value10 = (supply * ranges[usingRange].reserve0) / ranges[usingRange].supplyCoefficient;
      h.value11 = (supply * ranges[usingRange].reserve1) / ranges[usingRange].supplyCoefficient;
      h.value00 += h.value10;
      h.value01 += h.value11;
      _updateRangeReserves(usingRange, h.value10, h.value11, false, false, false);
      ranges[usingRange].supplyCoefficient -= supply;
    }
    //!!!
    TransferHelper.safeTransfer(token0, to, h.value00);
    TransferHelper.safeTransfer(token1, to, h.value01);
    h.balance0 = balance0();
    h.balance1 = balance1();
    //???
    require(h.balance0 >= h.lastBalance0 - h.value00 && h.balance1 >= h.lastBalance1 - h.value01, 'Pb2');

    emit Burn(ownerOf(ticketId), to, lowestRangeIndex, highestRangeIndex, ticketId, h.value00, h.value01);
    _burn(ticketId);
    //!!!
    _updateLastBalances(h.balance0, h.balance1);
    uint256 amount0 = h.value00;
    uint256 amount1 = h.value01;
    delete h;
    return (amount0, amount1);
  }

  /// inherit doc from IDesreSwapV0Pool
  function flash(
    address recipient,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external override {
    uint256 fee0 = (amount0 * fee) / E6;
    uint256 fee1 = (amount1 * fee) / E6;
    uint256 balance0Before = balance0();
    uint256 balance1Before = balance1();

    if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
    if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);

    IDesireSwapV0FlashCallback(msg.sender).desireSwapV0FlashCallback(fee0, fee1, data);

    uint256 balance0After = balance0();
    uint256 balance1After = balance1();

    require(balance0Before + fee0 <= balance0After, 'Pf0');
    require(balance1Before + fee1 <= balance1After, 'Pf1');

    uint256 paid0 = balance0After - balance0Before;
    uint256 paid1 = balance1After - balance1Before;

    _updateLastBalances(balance0After, balance1After);

    emit Flash(msg.sender, recipient, amount0, amount1, paid0, paid1);
  }

  ///
  /// OWNER ACTIONS
  ///

  /// note method that is used during initialization to calculated priceRanges of starting Range
  function startingSqrtPriceBottom(int24 _startingInUseRange) private view returns (uint256 startingSqrtPriceBottom_) {
    startingSqrtPriceBottom_ = E18;
    uint256 multiplier = sqrtRangeMultiplier;
    uint256 multiplier100 = sqrtRangeMultiplier100;
    while (_startingInUseRange > 0) {
      if(_startingInUseRange > 100){
       startingSqrtPriceBottom_ = (startingSqrtPriceBottom_ * multiplier100) / E18;
      _startingInUseRange = _startingInUseRange - 100;
      }else{
      startingSqrtPriceBottom_ = (startingSqrtPriceBottom_ * multiplier) / E18;
      _startingInUseRange--;
      }
    }
    while (_startingInUseRange < 0) {
      if(_startingInUseRange > 100){
       startingSqrtPriceBottom_ = (startingSqrtPriceBottom_ * E18) / multiplier100;
      _startingInUseRange = _startingInUseRange + 100;
      }else{
      startingSqrtPriceBottom_ = (startingSqrtPriceBottom_ * E18) / multiplier;
      _startingInUseRange++;
      }
    }
    return startingSqrtPriceBottom_;
  }

  /// inherit doc from IDesreSwapV0Pool
  function initialize(int24 _startingInUseRange) external override {
    require(msg.sender == IDesireSwapV0Factory(factory).owner(), 'Pi0');
    require(initialized == false, 'Pi1');
    ranges[_startingInUseRange].sqrtPriceBottom = startingSqrtPriceBottom(_startingInUseRange);
    ranges[_startingInUseRange].activated = true;
    initialized = true;
    inUseRange = _startingInUseRange;
    highestActivatedRange = _startingInUseRange;
    lowestActivatedRange = _startingInUseRange;
  }

  /// inherit doc from IDesreSwapV0Pool
  function collectFee(address token, uint256 amount) external override {
    require(msg.sender == IDesireSwapV0Factory(factory).owner(), 'PcF0');
    TransferHelper.safeTransfer(token, IDesireSwapV0Factory(factory).feeCollector(), amount);
    require(IERC20(token0).balanceOf(address(this)) >= totalReserve0 && IERC20(token1).balanceOf(address(this)) >= totalReserve1, 'PcF1');
    emit CollectFee(token, amount);
  }

  /// inherit doc from IDesreSwapV0Pool
  function setProtocolFee(bool _protocolFeeIsOn, uint256 _protocolFeePart) external override {
    require(msg.sender == IDesireSwapV0Factory(factory).owner(), 'PsPF0');
    protocolFeeIsOn = _protocolFeeIsOn;
    protocolFeePart = _protocolFeePart;
  }

  /// inherit doc from IDesreSwapV0Pool
  function setSwapRouter() external override {
    swapRouter = IDesireSwapV0Factory(factory).swapRouter();
  }
}
