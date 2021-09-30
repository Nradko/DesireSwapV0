// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolEvents {
  event InUseRangeChanged(int24 indexed oldIndex, int24 indexed newIndex);
  event Swap(address indexed msgSender, address indexed to, uint256 indexed blockNumber, int256 delta0, int256 delta1);
  event Mint(address msgSender, address indexed to, int24 indexed lowestRangeIndex, int24 indexed highestRangeIndex, uint256 ticketID, uint256 liqAdded, uint256 amount0Added, uint256 amount1Added);
  event Burn(address indexed to, address recipient, int24 indexed lowestRangeIndex, int24 indexed highestRangeIndex, uint256 ticketID, uint256 amount0Redeemed, uint256 amount1Redeemed);
  event Flash(address indexed msg_sender, address indexed recipient, uint256 amount0, uint256 amount1, uint256 paid0, uint256 paid1);
  event CollectFee(address indexed token, uint256 amount);
}
