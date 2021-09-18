// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolEvents {
  event SwapInRange(address msgSender, int24 index, bool zeroForOne, uint256 amountIn, uint256 amountOut, address to);
  event InUseRangeChanged(int24 index);
  event Swap(address msgSender, bool zeroForOne, int256 amount, address to);
  event Mint(address indexed to, uint256 ticketID);
  event Burn(address indexed owner, uint256 ticketID);
  event Flash(address msg_sender, address recipient, uint256 amount0, uint256 amount1, uint256 paid0, uint256 paid1);
  event CollectFee(address token, uint256 amount);
}
