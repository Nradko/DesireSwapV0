/*******************************************************
 * Copyright (C) 2021-2022 Konrad Wierzbik <desired.desire@protonmail.com>
 *
 * This file is part of DesireSwapProject and was developed by Konrad Konrad Wierzbik.
 *
 * DesireSwapProject files that are said to be developed by Konrad Wierzbik can not be copied 
 * and/or distributed without the express permission of Konrad Wierzbik.
 *******************************************************/
pragma solidity ^0.8.0;

import '../libraries/PoolHelper.sol';
import '../interfaces/IDesireSwapV0Pool.sol';
import '../interfaces/IDesireSwapV0Factory.sol';
import '../interfaces/ISwapRouterHelper.sol';

import 'hardhat/console.sol';

contract SwapRouterHelper is ISwapRouterHelper {
  uint256 private constant E18 = 10**18;

  address public immutable factory;

  constructor(address factory_) {
    factory = factory_;
  }

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

  function getPool(
    address tokenA,
    address tokenB,
    uint256 fee
  ) private view returns (IDesireSwapV0Pool) {
    return IDesireSwapV0Pool(IDesireSwapV0Factory(factory).poolAddress(tokenA, tokenB, fee));
  }

  function _swapInRange(
    IDesireSwapV0Pool pool,
    uint256 feePercentage,
    int24 index,
    bool zeroForOne,
    uint256 amountOut
  ) private view returns (uint256 amountIn, int24 indexReturn) {
    require(amountOut > 0, 'DSV0POOL(swapInRange): try different amount IN');
    HelpData memory h;
    (h.lastBalance0, h.lastBalance1) = pool.getLastBalances();
    (h.value00, h.value01, h.value10, h.value11, , ) = pool.getFullRangeInfo(index);
    require((zeroForOne && amountOut <= h.value01) || (!zeroForOne && amountOut <= h.value00), 'DSV0POOL(swapInRange): INSUFFICIENT_POSITION_LIQ');
    uint256 amountInHelp = PoolHelper.AmountIn(zeroForOne, h.value00, h.value01, h.value10, h.value11, amountOut); // do not include fees;
    uint256 collectedFee = (amountInHelp * feePercentage) / E18;
    amountIn = amountInHelp + collectedFee;
    if (pool.protocolFeeIsOn()) {
      amountInHelp = amountIn - (collectedFee * pool.protocolFeePart()) / E18; //amountIn - protocolFee. It is amount that is added to reserve
    }
    if (zeroForOne) {
      require(amountOut <= h.value01, 'DSV0POOL(swapInRange): ETfT error');
      if (amountOut == h.value01) index--;
    } else {
      require(amountOut <= h.value00, 'DSV0POOL(swapInRange): ETfT error');
      if (amountOut == h.value01) index++;
    }
    indexReturn = index;
    delete h;
  }

  struct SwapParams {
    IDesireSwapV0Pool pool;
    bool zeroForOne;
    int256 amount;
    uint256 sqrtPriceLimit;
  }

  function swapQuoter(
    address tokenA,
    address tokenB,
    uint256 fee,
    bool zeroForOne,
    int256 amount,
    uint256 sqrtPriceLimit
  ) public view override returns (int256, int256) {
    IDesireSwapV0Pool pool = getPool(tokenA, tokenB, fee);
    uint256 feePercentage = pool.feePercentage();
    SwapParams memory s = SwapParams({pool: pool, zeroForOne: zeroForOne, amount: amount, sqrtPriceLimit: sqrtPriceLimit});
    HelpData memory h;
    (h.lastBalance0, h.lastBalance1) = pool.getLastBalances();
    uint256 usingReserve;
    uint256 amountRecieved;
    uint256 amountSend;
    uint256 remained;
    int24 usingRange = pool.inUseRange();
    (h.balance0, h.balance1) = pool.getTotalReserves();
    // tokensForExactTokens
    // token0 In, token1 Out, tokensForExactTokens
    if (s.amount < 0) {
      remained = uint256(-s.amount);
      if (s.zeroForOne) {
        require(remained <= h.balance1, 'DSV0POOL(swap): TR1');
        (, usingReserve, h.value10, h.value11, , ) = pool.getFullRangeInfo(usingRange);
      } else {
        require(remained <= h.balance0, 'DSV0POOL(swap): TR0');
        (usingReserve, , h.value10, h.value11, , ) = pool.getFullRangeInfo(usingRange);
      }
      while (remained > usingReserve && ((s.zeroForOne ? sqrtPriceLimit > (h.value11) / E18 : sqrtPriceLimit < h.value10) || sqrtPriceLimit == 0)) {
        (h.balance0, usingRange) = _swapInRange(s.pool, feePercentage, usingRange, s.zeroForOne, usingReserve);
        amountRecieved += h.balance0;
        remained -= usingReserve;
        (h.value00, h.value01, h.value10, h.value11, , ) = pool.getFullRangeInfo(usingRange);
        usingReserve = s.zeroForOne ? h.value01 : h.value00;
      }
      (h.balance0, usingRange) = _swapInRange(s.pool, feePercentage, usingRange, s.zeroForOne, remained);
      amountRecieved += h.balance0;
      amountSend = uint256(-s.amount);
    }
    //
    //  exactTokensForTokens
    //
    else if (s.amount > 0) {
      remained = uint256(s.amount);
      uint256 predictedFee = (remained * feePercentage) / E18;
      (h.value00, h.value01, h.value10, h.value11, , ) = pool.getFullRangeInfo(usingRange);
      uint256 amountOut = PoolHelper.AmountOut(s.zeroForOne, h.value00, h.value01, h.value10, h.value11, remained - predictedFee);
      (h.balance0, h.balance1) = pool.getTotalReserves();
      require(amountOut <= (s.zeroForOne ? h.balance1 : h.balance0), 'DSV0POOL(swap): totalReserve to small');
      while (amountOut > (s.zeroForOne ? h.value01 : h.value00) && ((s.zeroForOne ? sqrtPriceLimit > (h.value11) / E18 : sqrtPriceLimit < h.value10) || sqrtPriceLimit == 0)) {
        (h.balance0, usingRange) = _swapInRange(s.pool, feePercentage, usingRange, s.zeroForOne, s.zeroForOne ? h.value01 : h.value00);
        remained -= h.balance0;
        amountSend += s.zeroForOne ? h.value01 : h.value00;
        predictedFee = (remained * feePercentage) / E18;
        (h.value00, h.value01, h.value10, h.value11, , ) = pool.getFullRangeInfo(usingRange);
        amountOut = PoolHelper.AmountOut(s.zeroForOne, h.value00, h.value01, h.value10, h.value11, remained - predictedFee);
      }
      (h.balance0, usingRange) = _swapInRange(s.pool, feePercentage, usingRange, s.zeroForOne, amountOut);
      require(h.balance0 <= remained, 'DSV0POOL(swap): Try different amountIN');
      remained -= h.balance0;
      amountSend += amountOut;
      amountRecieved = uint256(s.amount) - remained;
    }
    delete s;
    delete h;
    if (s.zeroForOne) {
      return (int256(amountRecieved), -int256(amountSend));
    } else {
      return (-int256(amountSend), int256(amountRecieved));
    }
  }
}
