// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.0;

// import './libraries/PoolHelper.sol';
// import './interfaces/IDesireSwapV0Pool.sol';

// contract TransactionHelper {
//   uint256 private constant D = 10**18;
//   uint256 private constant d = 10**9;

//   function token0only(int24 index, uint256 liqToAdd) private returns (uint256) {
//     if (!ranges[index].activated) return 0;
//     (uint256 reserve0, uint256 reserve1, uint256 sqrtPriceBottom, uint256 sqrtPriceTop) = IDesireSwapV0Pool(poolAddress).getRangeInfo(index);
//     return (liqToAdd * D * (sqrtPriceTop - sqrtPriceBottom)) / (sqrtPriceBottom * sqrtPriceTop);
//   }

//   function token1only(int24 index, uint256 liqToAdd) private returns (uint256 amount1ToAdd) {
//     if (!ranges[index].activated) return 0;
//     (uint256 reserve0, uint256 reserve1, uint256 sqrtPriceBottom, uint256 sqrtPriceTop) = getRangeInfo(index);

//     amount1ToAdd = (liqToAdd * (sqrtPriceTop - sqrtPriceBottom)) / D;

//     if (ranges[index].supplyCoefficient != 0) {
//       _ticketSupplyData[ticketId][index] = (ranges[index].supplyCoefficient * amount1ToAdd) / reserve1;
//     } else {
//       _ticketSupplyData[ticketId][index] = PoolHelper.LiqCoefficient(0, amount1ToAdd, sqrtPriceBottom, sqrtPriceTop);
//     }
//     ranges[index].supplyCoefficient += _ticketSupplyData[ticketId][index];
//     //!!
//     _modifyRangeReserves(index, 0, amount1ToAdd, true, true);
//   }

//   function token0Supply(
//     address poolAddress,
//     uint256 amount0,
//     uint256 sqrtBottom,
//     uint256 sqrtTop
//   ) public view returns (uint256, uint256) {
//     uint256 currentPrice = currentPrice(poolAddress);
//     uint256 sqrtPrice = sqrt(currentPrice);
//     require(sqrtTop > sqrtPrice, 'supply onnly token1');
//     uint256 L = (amount0 * (sqrtPrice * sqrtTop)) / (sqrtTop - sqrtPrice) / D;

//     require(highestRangeIndex >= lowestRangeIndex);
//     int24 usingRange = IDesireSwapV0Pool(poolAddress).inUseRange();
//   }

//   function token1Supply(
//     address poolAddress,
//     uint256 amount1,
//     int24 lowestIndex,
//     int24 highestIndex
//   ) public view returns (uint256, uint256) {
//     uint256 currentPrice = currentPrice(poolAddress);
//     uint256 sqrtPrice = sqrt(currentPrice);

//     (, , uint256 sqrtBottom, ) = IDesireSwapV0Pool(poolAddress).getRangeInfo(lowestIndex);
//     (, , , uint256 sqrtTop) = IDesireSwapV0Pool(poolAddress).getRangeInfo(highestIndex);
//     require(sqrtBottom < sqrtPrice);
//     uint256 L = (amountToAdd * (sqrtBottom * sqrtTop)) / (sqrtTop - sqrtPrice);
//     if (sqrtBottom > sqrtPrice) return (L / D, 0);

//     uint256 amount1 = (((sqrtPrice - sqrtBottom) / d) * L) / D / d;
//     return (L / D, amount1);

//     if (lowestRangeIndex > usingRange) {
//       //in this case ranges.reserve1 should be 0
//       for (int24 i = highestRangeIndex; i >= lowestRangeIndex; i--) {
//         amount0 += _printOnTicket1(i, ticketId, liqToAdd);
//       }
//     } else if (highestRangeIndex < usingRange) {
//       // in this case ranges.reserve0 should be 0
//       for (int24 i = lowestRangeIndex; i <= highestRangeIndex; i++) {
//         amount1 += _printOnTicket0(i, ticketId, liqToAdd);
//       }
//     } else {
//       for (int24 i = usingRange + 1; i <= highestRangeIndex; i++) {
//         amount0 += _printOnTicket1(i, ticketId, liqToAdd);
//       }
//       for (int24 i = usingRange - 1; i >= lowestRangeIndex; i--) {
//         amount1 += _printOnTicket0(i, ticketId, liqToAdd);
//       }

//       if (!ranges[usingRange].activated) activate(usingRange);
//       (h.value00, h.value01, h.value10, h.value11) = getRangeInfo(usingRange);
//       uint256 LiqCoefBefore = PoolHelper.LiqCoefficient(h.value00, h.value01, h.value10, h.value11);
//       uint256 amount0ToAdd;
//       uint256 amount1ToAdd;
//       if (h.value00 == 0 && h.value01 == 0) {
//         amount0ToAdd = (liqToAdd * D * (h.value11 - h.value10)) / (h.value10 * h.value11) / 2;
//         amount1ToAdd = (liqToAdd * (h.value11 - h.value10)) / D / 2;
//       } else {
//         amount0ToAdd = ((liqToAdd / LiqCoefBefore) * h.value00) / d;
//         amount1ToAdd = ((liqToAdd / LiqCoefBefore) * h.value01) / d;
//       }
//       uint256 LiqCoefAfter = PoolHelper.LiqCoefficient(h.value00 + amount0ToAdd, h.value01 + amount1ToAdd, h.value10, h.value11);
//       // require(LiqCoefAfter >= LiqCoefBefore + liqToAdd*d, "DesireSwapV0: LIQ_ERROR");

//       amount0 += amount0ToAdd;
//       amount1 += amount1ToAdd;
//     }
//   }
// }
