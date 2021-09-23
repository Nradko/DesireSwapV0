// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './libraries/PoolHelper.sol';
import './interfaces/IDesireSwapV0Pool.sol';

import 'hardhat/console.sol';

contract SwapRouterHelper {
  uint256 private constant D = 10**18;
  uint256 private constant d = 10**9;

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
    address poolAddress,
    uint256 feePercentage,
    int24 index,
    bool zeroForOne,
    uint256 amountOut
  ) private view returns (uint256 amountIn, int24 indexReturn) {
    require(amountOut > 0, 'DSV0POOL(swapInRange): try different amount IN');
    helpData memory h;
    (h.lastBalance0, h.lastBalance1) = IDesireSwapV0Pool(poolAddress).getLastBalances();
    (h.value00, h.value01, h.value10, h.value11) = IDesireSwapV0Pool(poolAddress).getRangeInfo(index);
    require((zeroForOne && amountOut <= h.value01) || (!zeroForOne && amountOut <= h.value00), 'DSV0POOL(swapInRange): INSUFFICIENT_POSITION_LIQ');
    uint256 amountInHelp = PoolHelper.AmountIn(zeroForOne, h.value00, h.value01, h.value10, h.value11, amountOut); // do not include fees;
    uint256 collectedFee = (amountInHelp * feePercentage) / D;
    amountIn = amountInHelp + collectedFee;
    if (IDesireSwapV0Pool(poolAddress).protocolFeeIsOn()) {
      amountInHelp = amountIn - (collectedFee * IDesireSwapV0Pool(poolAddress).protocolFeePart()) / D; //amountIn - protocolFee. It is amount that is added to reserve
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

  struct swapParams {
    address poolAddress;
    bool zeroForOne;
    int256 amount;
    uint256 sqrtPriceLimit;
  }

  function swapQuoter(
    address poolAddress,
    bool zeroForOne,
    int256 amount,
    uint256 sqrtPriceLimit
  ) public view returns (int256, int256) {
    uint256 feePercentage = IDesireSwapV0Pool(poolAddress).feePercentage();
    swapParams memory s = swapParams({poolAddress: poolAddress, zeroForOne: zeroForOne, amount: amount, sqrtPriceLimit: sqrtPriceLimit});
    helpData memory h;
    (h.lastBalance0, h.lastBalance1) = IDesireSwapV0Pool(poolAddress).getLastBalances();
    uint256 usingReserve;
    uint256 amountRecieved;
    uint256 amountSend;
    uint256 remained;
    int24 usingRange = IDesireSwapV0Pool(s.poolAddress).inUseRange();
    (h.balance0, h.balance1) = IDesireSwapV0Pool(s.poolAddress).getTotalReserves();
    // tokensForExactTokens
    // token0 In, token1 Out, tokensForExactTokens
    if (s.amount < 0) {
      remained = uint256(-s.amount);
      if (s.zeroForOne) {
        require(remained <= h.balance1, 'DSV0POOL(swap): TR1');
        (, usingReserve, h.value10, h.value11) = IDesireSwapV0Pool(s.poolAddress).getRangeInfo(usingRange);
      } else {
        require(remained <= h.balance0, 'DSV0POOL(swap): TR0');
        (usingReserve, , h.value10, h.value11) = IDesireSwapV0Pool(s.poolAddress).getRangeInfo(usingRange);
      }
      while (remained > usingReserve && ((s.zeroForOne ? sqrtPriceLimit > (h.value11) / D : sqrtPriceLimit < h.value10) || sqrtPriceLimit == 0)) {
        (h.balance0, usingRange) = _swapInRange(s.poolAddress, feePercentage, usingRange, s.zeroForOne, usingReserve);
        amountRecieved += h.balance0;
        remained -= usingReserve;
        (h.value00, h.value01, h.value10, h.value11) = IDesireSwapV0Pool(s.poolAddress).getRangeInfo(usingRange);
        usingReserve = s.zeroForOne ? h.value01 : h.value00;
      }
      (h.balance0, usingRange) = _swapInRange(s.poolAddress, feePercentage, usingRange, s.zeroForOne, remained);
      amountRecieved += h.balance0;
      amountSend = uint256(-s.amount);
    }
    //
    //  exactTokensForTokens
    //
    else if (s.amount > 0) {
      remained = uint256(s.amount);
      uint256 predictedFee = (remained * feePercentage) / D;
      (h.value00, h.value01, h.value10, h.value11) = IDesireSwapV0Pool(s.poolAddress).getRangeInfo(usingRange);
      uint256 amountOut = PoolHelper.AmountOut(s.zeroForOne, h.value00, h.value01, h.value10, h.value11, remained - predictedFee);
      (h.balance0, h.balance1) = IDesireSwapV0Pool(s.poolAddress).getTotalReserves();
      require(amountOut <= (s.zeroForOne ? h.balance1 : h.balance0), 'DSV0POOL(swap): totalReserve to small');
      while (amountOut > (s.zeroForOne ? h.value01 : h.value00) && ((s.zeroForOne ? sqrtPriceLimit > (h.value11) / D : sqrtPriceLimit < h.value10) || sqrtPriceLimit == 0)) {
        (h.balance0, usingRange) = _swapInRange(s.poolAddress, feePercentage, usingRange, s.zeroForOne, s.zeroForOne ? h.value01 : h.value00);
        remained -= h.balance0;
        amountSend += s.zeroForOne ? h.value01 : h.value00;
        predictedFee = (remained * feePercentage) / D;
        (h.value00, h.value01, h.value10, h.value11) = IDesireSwapV0Pool(s.poolAddress).getRangeInfo(usingRange);
        amountOut = PoolHelper.AmountOut(s.zeroForOne, h.value00, h.value01, h.value10, h.value11, remained - predictedFee);
      }
      (h.balance0, usingRange) = _swapInRange(s.poolAddress, feePercentage, usingRange, s.zeroForOne, amountOut);
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
