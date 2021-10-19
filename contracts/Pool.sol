/*******************************************************
 * Copyright (C) 2021-2022 Konrad Wierzbik <desired.desire@protonmail.com>
 *
 * This file is part of DesireSwapProject.
 *
 * DesireSwapProject can not be copied and/or distributed without the express
 * permission of Konrad Wierzbik
 *******************************************************/

pragma solidity ^0.8.0;
pragma abicoder v2;

import './base/Ticket.sol';
import './libraries/PoolHelper.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IDesireSwapV0Factory.sol';
import './interfaces/IDesireSwapV0Pool.sol';

import './interfaces/callback/IDesireSwapV0MintCallback.sol';
import './interfaces/callback/IDesireSwapV0SwapCallback.sol';
import './interfaces/callback/IDesireSwapV0FlashCallback.sol';

import 'hardhat/console.sol';

contract DesireSwapV0Pool is Ticket, IDesireSwapV0Pool {
  bool public override initialized;
  bool public override protocolFeeIsOn = true;

  address public immutable override factory;
  address public immutable override token0;
  address public immutable override token1;
  address public override swapRouter;

  uint256 private constant d = 10**9;
  uint256 private constant D = 10**18;
  uint256 private constant DD = 10**36;
  uint256 private constant tickSize = 1000049998750062496;
  uint256 private immutable ticksInRange;
  uint256 public immutable override sqrtRangeMultiplier; // example: 100100000.... is 1.001 (* 10**)
  uint256 public immutable override feePercentage; //  0 fee is 0 // 100% fee is 1* 10**18;
  uint256 public override protocolFeePart = 2 * 10**17;
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
    uint256 feePercentage_,
    uint256 ticksInRange_,
    string memory name_,
    string memory symbol_
  ) Ticket(name_, symbol_) {
    initialized = false;
    factory = factory_;
    swapRouter = swapRouter_;
    token0 = token0_;
    token1 = token1_;
    ticksInRange = ticksInRange_;
    feePercentage = feePercentage_;
    uint256 sqrtRangeMultiplier_ = D;
    while (ticksInRange_ > 0) {
      sqrtRangeMultiplier_ = (sqrtRangeMultiplier_ * tickSize) / D;
      console.log(sqrtRangeMultiplier_);
      ticksInRange_--;
    }
    sqrtRangeMultiplier = sqrtRangeMultiplier_;
  }

  ///
  /// VIEW
  ///
  function balance0() public view override returns (uint256) {
    return IERC20(token0).balanceOf(address(this));
  }

  function balance1() public view override returns (uint256) {
    return IERC20(token1).balanceOf(address(this));
  }

  function getLastBalances() external view override returns (uint256 _lastBalance0, uint256 _lastBalance1) {
    _lastBalance0 = lastBalance0;
    _lastBalance1 = lastBalance1;
  }

  function getTotalReserves() external view override returns (uint256 _totalReserve0, uint256 _totalReserve1) {
    _totalReserve0 = totalReserve0;
    _totalReserve1 = totalReserve1;
  }

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
    _sqrtPriceTop = (_sqrtPriceBottom * sqrtRangeMultiplier) / D;
  }

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
    _sqrtPriceTop = (_sqrtPriceBottom * sqrtRangeMultiplier) / D;
    _supplyCoefficient = ranges[index].supplyCoefficient;
    _activated = ranges[index].activated;
  }

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
    inUseLiq = PoolHelper.LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
    sqrtCurrentPrice = (inUseLiq * D) / (reserve0 + (inUseLiq * D) / sqrt1);
    inUseReserve0 = reserve0;
    inUseReserve1 = reserve1;
  }

  ///
  /// private
  ///
  function _updateLastBalances(uint256 _lastBalance0, uint256 _lastBalance1) private {
    lastBalance0 = _lastBalance0;
    lastBalance1 = _lastBalance1;
  }

  function _modifyRangeReserves(
    int24 index,
    uint256 toAdd0,
    uint256 toAdd1,
    bool add0, /// add or substract
    bool add1,
    bool isSwap
  ) private {
    ranges[index].reserve0 = add0 ? ranges[index].reserve0 + toAdd0 : ranges[index].reserve0 - toAdd0;
    ranges[index].reserve1 = add1 ? ranges[index].reserve1 + toAdd1 : ranges[index].reserve1 - toAdd1;
    totalReserve0 = add0 ? totalReserve0 + toAdd0 : totalReserve0 - toAdd0;
    totalReserve1 = add1 ? totalReserve1 + toAdd1 : totalReserve1 - toAdd1;

    if (isSwap) {
      if (ranges[index].reserve0 == 0 && ranges[index + 1].activated) {
        inUseRange++;
        emit InUseRangeChanged(index - 1, index);
      }
      if (ranges[index].reserve1 == 0 && ranges[index - 1].activated) {
        inUseRange--;
        emit InUseRangeChanged(index + 1, index);
      }
    }
  }

  ///
  /// Range activation
  ///
  function activatePrivate(int24 index) private {
    require(!ranges[index].activated, 'POOL(activatePrivate): PAA');
    if (index > highestActivatedRange) {
      if (!ranges[index - 1].activated) activate(index - 1);
      ranges[index].sqrtPriceBottom = (ranges[index - 1].sqrtPriceBottom * sqrtRangeMultiplier) / D;
    } else if (index < lowestActivatedRange) {
      if (!ranges[index + 1].activated) activate(index + 1);
      ranges[index].sqrtPriceBottom = (ranges[index + 1].sqrtPriceBottom * D) / sqrtRangeMultiplier;
    }
    ranges[index].activated = true;
  }

  function activate(int24 index) public override {
    require(!ranges[index].activated, 'POOL(activate): PAA');
    if (index > highestActivatedRange) {
      for (int24 i = highestActivatedRange + 1; i <= index; i++) {
        ranges[i].sqrtPriceBottom = (ranges[i - 1].sqrtPriceBottom * sqrtRangeMultiplier) / D;
        ranges[i].activated = true;
      }
      highestActivatedRange = index;
    } else if (index < lowestActivatedRange) {
      for (int24 i = lowestActivatedRange - 1; i >= index; i--) {
        ranges[i].sqrtPriceBottom = (ranges[i + 1].sqrtPriceBottom * D) / sqrtRangeMultiplier;
        ranges[i].activated = true;
      }
      lowestActivatedRange = index;
    }
  }

  ///
  /// POOL ACTIONS
  ///

  /// Swapping

  // below function make swap inside only one position. It is used to make "whole" swap.
  // it swaps token0 to token1 if zeroForOne, else it swaps token1 to token 0.
  // it swaps tokensForExactTokens only.
  // amountOut is amount transfered to address "to"
  // !! IT TRANSFERS TOKENS OUT OF POOL !!
  // !! IT MODIFIES IMPORTANT DATA !!

  struct helpData {
    uint256 lastBalance0;
    uint256 lastBalance1;
    uint256 balance0;
    uint256 balance1;
    uint256 value00;
    uint256 value01;
    uint256 value10;
    uint256 value11;
  }

  function _swapInRange(
    int24 index,
    bool zeroForOne,
    uint256 amountOut
  ) private returns (uint256 amountIn) {
    require(amountOut > 0, 'POOL(swapInRange): try different amount IN');
    require(index == inUseRange, 'POOL(swapInRange): WI');
    helpData memory h = helpData({
      lastBalance0: lastBalance0,
      lastBalance1: lastBalance1,
      balance0: 0,
      balance1: 0,
      value00: ranges[index].reserve0,
      value01: ranges[index].reserve1,
      value10: ranges[index].sqrtPriceBottom,
      value11: 0
    });

    h.value11 = (h.value10 * sqrtRangeMultiplier) / D;
    require((zeroForOne && amountOut <= h.value01) || (!zeroForOne && amountOut <= h.value00), 'POOL(swapInRange): INSUFFICIENT_POSITION_LIQ');
    uint256 amountInHelp = PoolHelper.AmountIn(zeroForOne, h.value00, h.value01, h.value10, h.value11, amountOut); // do not include fees;
    uint256 collectedFee = (amountInHelp * feePercentage) / D;
    amountIn = amountInHelp + collectedFee;
    if (protocolFeeIsOn) {
      amountInHelp = amountIn - (collectedFee * protocolFeePart) / D; //amountIn - protocolFee. It is amount that is added to reserve
    }
    if (zeroForOne) {
      //??
      require(
        PoolHelper.LiqCoefficient(h.value00 + amountInHelp, h.value01 - amountOut, h.value10, h.value11) >= PoolHelper.LiqCoefficient(h.value00, h.value01, h.value10, h.value11),
        'POOL(swapInRange): LIQ_COEFFICIENT_IS_TOO_LOW'
      ); //assure that after swap there is more o r equal liquidity. If PoolHelper.AmountIn works correctly it can be removed.
      //!!
      require(amountOut <= h.value01, 'POOL(swapInRange): ETfT error');
      _modifyRangeReserves(index, amountInHelp, amountOut, true, false, true);
    }
    // token1 for token0 // token1 in; token0 out;
    else {
      //??
      require(
        PoolHelper.LiqCoefficient(h.value00 - amountOut, h.value01 + amountInHelp, h.value10, h.value11) >= PoolHelper.LiqCoefficient(h.value00, h.value01, h.value10, h.value11),
        'POOL(swapInRange): LIQ_COEFFICIENT_IS_TOO_LOW'
      ); //assure that after swap there is more or equal liquidity. If PoolHelper.AmountIn works correctly it can be removed.
      //!!
      require(amountOut <= h.value00, 'POOL(swapInRange): ETfT error');
      _modifyRangeReserves(index, amountOut, amountInHelp, false, true, true);
    }
    delete h;
  }

  // This function uses swapInRange to make any swap.
  // The calldata is not yet used. SwapRoutes!!!!!!!
  // amount > 0 amount is exact token inflow, amount < 0 amount is exact token outflow.
  // sqrtPriceLimit is price

  struct swapParams {
    address to;
    bool zeroForOne;
    int256 amount;
    bytes data;
  }

  function swap(
    address to,
    bool zeroForOne,
    int256 amount,
    bytes calldata data
  ) external override returns (int256, int256) {
    if (msg.sender != swapRouter) require(IDesireSwapV0Factory(factory).whitelisted(msg.sender), 'POOL(swap): not_whitelisted');
    swapParams memory s = swapParams({to: to, zeroForOne: zeroForOne, amount: amount, data: data});
    helpData memory h = helpData({lastBalance0: lastBalance0, lastBalance1: lastBalance1, balance0: 0, balance1: 0, value00: 0, value01: 0, value10: 0, value11: 0});
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
        require(remained <= totalReserve1, 'POOL(swap): TR1');
        usingReserve = ranges[usingRange].reserve1;
      } else {
        require(remained <= totalReserve0, 'POOL(swap): TR0');
        usingReserve = ranges[usingRange].reserve0;
      }
      while (remained > usingReserve) {
        amountRecieved += _swapInRange(usingRange, s.zeroForOne, usingReserve);
        remained -= usingReserve;
        usingRange = inUseRange;
        usingReserve = s.zeroForOne ? ranges[usingRange].reserve1 : ranges[usingRange].reserve0;
      }
      amountRecieved += _swapInRange(usingRange, s.zeroForOne, remained);
      amountSend = uint256(-s.amount);
    }
    //
    //  exactTokensForTokens
    //
    else if (s.amount > 0) {
      remained = uint256(s.amount);
      uint256 predictedFee = (remained * feePercentage) / D;
      (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(usingRange);
      uint256 amountOut = PoolHelper.AmountOut(s.zeroForOne, h.value00, h.value01, h.value10, h.value11, remained - predictedFee);
      require(amountOut <= (s.zeroForOne ? totalReserve1 : totalReserve0), 'POOL(swap): totalReserve to small');
      while (amountOut > (s.zeroForOne ? h.value01 : h.value00)) {
        remained -= _swapInRange(usingRange, s.zeroForOne, s.zeroForOne ? h.value01 : h.value00);
        amountSend += s.zeroForOne ? h.value01 : h.value00;
        predictedFee = (remained * feePercentage) / D;
        usingRange = inUseRange;
        (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(usingRange);
        amountOut = PoolHelper.AmountOut(s.zeroForOne, h.value00, h.value01, h.value10, h.value11, remained - predictedFee);
      }
      uint256 help = _swapInRange(usingRange, s.zeroForOne, amountOut);
      require(help <= remained, 'POOL(swap): Try different amountIN');
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
      require(h.balance0 >= h.lastBalance0 + amountRecieved && h.balance1 >= h.lastBalance1 - amountSend, 'POOL(swap): BALANCES_ARE_T0O_LOW');
    } else {
      require(h.balance1 >= h.lastBalance1 + amountRecieved && h.balance0 >= h.lastBalance0 - amountSend, 'POOL(swap): BALANCES_ARE_T0O_LOW');
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

  //  The proof of being LP is Ticket that stores information of how much liquidity was provided.
  //  It is minted when L is provided.
  //  It is burned when L is taken.

  function _printOnTicket0(
    int24 index,
    uint256 ticketId,
    uint256 liqToAdd
  ) private returns (uint256 amount0ToAdd) {
    if (!ranges[index].activated) activate(index);
    (
      uint256 reserve0, /*unused*/
      ,
      uint256 sqrtPriceBottom,
      uint256 sqrtPriceTop
    ) = getRangeInfo(index);
    amount0ToAdd = (liqToAdd * D * (sqrtPriceTop - sqrtPriceBottom)) / (sqrtPriceBottom * sqrtPriceTop);
    if (ranges[index].supplyCoefficient != 0) {
      _ticketSupplyData[ticketId][index] = (ranges[index].supplyCoefficient * amount0ToAdd) / reserve0;
    } else {
      _ticketSupplyData[ticketId][index] = PoolHelper.LiqCoefficient(amount0ToAdd, 0, sqrtPriceBottom, sqrtPriceTop);
    }
    ranges[index].supplyCoefficient += _ticketSupplyData[ticketId][index];
    //!!
    _modifyRangeReserves(index, amount0ToAdd, 0, true, true, false);
  }

  function _printOnTicket1(
    int24 index,
    uint256 ticketId,
    uint256 liqToAdd
  ) private returns (uint256 amount1ToAdd) {
    if (!ranges[index].activated) activate(index);
    (
      ,
      /*unused*/
      uint256 reserve1,
      uint256 sqrtPriceBottom,
      uint256 sqrtPriceTop
    ) = getRangeInfo(index);

    amount1ToAdd = (liqToAdd * (sqrtPriceTop - sqrtPriceBottom)) / D;

    if (ranges[index].supplyCoefficient != 0) {
      _ticketSupplyData[ticketId][index] = (ranges[index].supplyCoefficient * amount1ToAdd) / reserve1;
    } else {
      _ticketSupplyData[ticketId][index] = PoolHelper.LiqCoefficient(0, amount1ToAdd, sqrtPriceBottom, sqrtPriceTop);
    }
    ranges[index].supplyCoefficient += _ticketSupplyData[ticketId][index];
    //!!
    _modifyRangeReserves(index, 0, amount1ToAdd, true, true, false);
  }

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
    require(initialized, 'POOL(mint): not_initialized');
    require(highestRangeIndex >= lowestRangeIndex, 'POOL(mint): Indexes');
    helpData memory h = helpData({lastBalance0: lastBalance0, lastBalance1: lastBalance1, balance0: balance0(), balance1: balance1(), value00: 0, value01: 0, value10: 0, value11: 0});
    ticketId = getNextTicketId();
    _safeMint(to, _nextTicketId++);
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
      if (!ranges[usingRange].activated) activate(usingRange);
      (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(usingRange);
      uint256 LiqCoefBefore = PoolHelper.LiqCoefficient(h.value00, h.value01, h.value10, h.value11);
      uint256 amount0ToAdd;
      uint256 amount1ToAdd;
      if (h.value00 == 0 && h.value01 == 0) {
        amount0ToAdd = (liqToAdd * D * (h.value11 - h.value10)) / (h.value10 * h.value11) / 2;
        amount1ToAdd = (liqToAdd * (h.value11 - h.value10)) / D / 2;
      } else {
        amount0ToAdd = (liqToAdd * h.value00) / LiqCoefBefore;
        amount1ToAdd = (liqToAdd * h.value01) / LiqCoefBefore;
      }
      uint256 LiqCoefAfter = PoolHelper.LiqCoefficient(h.value00 + amount0ToAdd, h.value01 + amount1ToAdd, h.value10, h.value11);
      // require(LiqCoefAfter >= LiqCoefBefore + liqToAdd, "DesireSwapV0: LIQ_ERROR");
      amount0 += amount0ToAdd;
      amount1 += amount1ToAdd;
      if (ranges[usingRange].supplyCoefficient != 0) {
        _ticketSupplyData[ticketId][usingRange] = (ranges[usingRange].supplyCoefficient * (LiqCoefAfter - LiqCoefBefore)) / LiqCoefBefore;
      } else {
        _ticketSupplyData[ticketId][usingRange] = LiqCoefAfter;
      }
      //!!
      ranges[usingRange].supplyCoefficient += _ticketSupplyData[ticketId][usingRange];
      //!!
      _modifyRangeReserves(usingRange, amount0ToAdd, amount1ToAdd, true, true, false);
    }
    IDesireSwapV0MintCallback(msg.sender).desireSwapV0MintCallback(amount0, amount1, data);
    ///???
    h.balance0 = balance0();
    h.balance1 = balance1();
    require(h.balance0 >= h.lastBalance0 + amount0 && h.balance1 >= h.lastBalance1 + amount1, 'POOL(mint): BALANCES_ARE_TOO_LOW');
    emit Mint(msg.sender, to, lowestRangeIndex, highestRangeIndex, ticketId, liqToAdd, amount0, amount1);
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
    bool sendZero
  ) private returns (uint256 amountToTransfer) {
    uint256 supply = _ticketSupplyData[ticketId][index];
    _ticketSupplyData[ticketId][index] = 0;
    if (sendZero) {
      amountToTransfer = (supply * ranges[index].reserve0) / ranges[index].supplyCoefficient;
      //!!
      _modifyRangeReserves(index, amountToTransfer, 0, false, false, false);
    } else {
      amountToTransfer = (supply * ranges[index].reserve1) / ranges[index].supplyCoefficient;
      //!!
      _modifyRangeReserves(index, 0, amountToTransfer, false, false, false);
    }
    //!!
    ranges[index].supplyCoefficient -= supply;
  }

  function burn(address to, uint256 ticketId) external override returns (uint256, uint256) {
    require(_exists(ticketId), 'POOL(burn): 0');
    require(_isApprovedOrOwner(_msgSender(), ticketId), 'POOL(burn): 1');
    helpData memory h;
    h.lastBalance0 = lastBalance0;
    h.lastBalance1 = lastBalance1;
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
      _modifyRangeReserves(usingRange, h.value10, h.value11, false, false, false);
      ranges[usingRange].supplyCoefficient -= supply;
    }
    //!!!
    TransferHelper.safeTransfer(token0, to, h.value00);
    TransferHelper.safeTransfer(token1, to, h.value01);
    h.balance0 = balance0();
    h.balance1 = balance1();
    //???
    require(h.balance0 >= h.lastBalance0 - h.value00 && h.balance1 >= h.lastBalance1 - h.value01, 'POOL(burn): BALANCES_ARE_TO0_LOW');

    emit Burn(ownerOf(ticketId), to, lowestRangeIndex, highestRangeIndex, ticketId, h.value00, h.value01);
    _burn(ticketId);
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
    bytes calldata data
  ) external override {
    uint256 fee0 = (amount0 * feePercentage) / D;
    uint256 fee1 = (amount1 * feePercentage) / D;
    uint256 balance0Before = balance0();
    uint256 balance1Before = balance1();

    if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
    if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);

    IDesireSwapV0FlashCallback(msg.sender).desireSwapV0FlashCallback(fee0, fee1, data);

    uint256 balance0After = balance0();
    uint256 balance1After = balance1();

    require(balance0Before + fee0 <= balance0After, 'POOL(flash): F0');
    require(balance1Before + fee1 <= balance1After, 'POOL(flash): F1');

    uint256 paid0 = balance0After - balance0Before;
    uint256 paid1 = balance1After - balance1Before;

    emit Flash(msg.sender, recipient, amount0, amount1, paid0, paid1);
  }

  ///
  /// OWNER ACTIONS
  ///
  //initialize helper
  function startingSqrtPriceBottom(int24 _startingInUseRange) private view returns (uint256 startingSqrtPriceBottom_) {
    startingSqrtPriceBottom_ = D;
    uint256 multiplier = sqrtRangeMultiplier;
    while (_startingInUseRange > 0) {
      startingSqrtPriceBottom_ = (startingSqrtPriceBottom_ * multiplier) / D;
      _startingInUseRange--;
    }
    while (_startingInUseRange < 0) {
      startingSqrtPriceBottom_ = (startingSqrtPriceBottom_ * D) / multiplier;
      _startingInUseRange++;
    }
    return startingSqrtPriceBottom_;
  }

  function initialize(int24 _startingInUseRange) external override {
    require(msg.sender == IDesireSwapV0Factory(factory).owner(), 'POOL(initialize): err1');
    require(initialized == false, 'POOL(initialized): err2');
    ranges[_startingInUseRange].sqrtPriceBottom = startingSqrtPriceBottom(_startingInUseRange);
    ranges[_startingInUseRange].activated = true;
    initialized = true;
    inUseRange = _startingInUseRange;
    highestActivatedRange = _startingInUseRange;
    lowestActivatedRange = _startingInUseRange;
  }

  function collectFee(address token, uint256 amount) external override {
    require(msg.sender == IDesireSwapV0Factory(factory).owner(), 'POOL(collectFee): err1');
    TransferHelper.safeTransfer(token, IDesireSwapV0Factory(factory).feeCollector(), amount);
    require(IERC20(token0).balanceOf(address(this)) >= totalReserve0 && IERC20(token1).balanceOf(address(this)) >= totalReserve1, 'POOL(collectFee): err2');
    emit CollectFee(token, amount);
  }

  function setProtocolFee(bool _protocolFeeIsOn, uint256 _protocolFeePart) external override {
    require(msg.sender == IDesireSwapV0Factory(factory).owner(), 'POOL(serProtocolFee): err');
    protocolFeeIsOn = _protocolFeeIsOn;
    protocolFeePart = _protocolFeePart;
  }

  function setSwapRouter() external override {
    swapRouter = IDesireSwapV0Factory(factory).swapRouter();
  }
}
