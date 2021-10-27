// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IDesireSwapV0PoolActions {
  
  /// note activates all ranges between range with index = index and closest activated range
  /// @param index index that set boundary of indexes to be activated
  function activate(int24 index) external;

  /// @notice Swap token0 for token1, or token1 for token0
  /// @dev The caller of this method receives a callback in the form of IDesireSwapV0SwapCallback
  /// @param to The address to receive the output of the swap
  /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
  /// @param amount amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
  /// @param data Any data to be passed through to the callback
  /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
  /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
  function swap(
    address to,
    bool zeroForOne,
    int256 amount,
    bytes calldata data
  ) external returns (int256, int256);

  /// note supply a pool and mint an ERC721 Token called Ticket that is used later to redeem funds.
  /// @dev The caller of this method receives a callback in the form of IDesireSwapV0MintCallback#DesireSwapV0MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity, and the current price.
  /// @dev important! The first suplly to the pool is put on risk of pernament loss! (less the 2% of capital)
    /// That is why 1st supply should be done with small amount of tokens!!   
  /// @param to address to recive Ticket
  /// @param lowestRangeIndex supply ranges with index >= lowestRangeIndex
  /// @param highestRangeIndex supply ranges with index <= highestRangeIndex
  /// @param liqToAdd liquidity that is added to ranges
  /// @param data anydata that will be passed to callback
  /// @return ticketId Id of ERC721 Token
  /// @return amount0 of token 0 added to pool
  /// @return amount1 of token 1 added to pool
  function mint(
    address to,
    int24 lowestRangeIndex,
    int24 highestRangeIndex,
    uint256 liqToAdd,
    bytes calldata data
  )
    external
    returns (
      uint256 ticketId,
      uint256 amount0,
      uint256 amount1
    );

  /// note burns the Ticked that and returns supplied funds
  /// @param to address to which the funds are transfered
  /// @param ticketId Id of token to be burnt
  /// @return (uint256,uint256) = (amount of token0 returned, amount of token1 returned)
  function burn(address to, uint256 ticketId) external returns (uint256, uint256);

    /// @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
    /// @dev The caller of this method receives a callback in the form of IDesireSwapV0FlashCallback#DesireSwapV0FlashCallback
    /// @dev Can be used to donate underlying tokens pro-rata to currently in-range liquidity providers by calling
    /// with 0 amount{0,1} and sending the donation amount(s) from the callback
    /// @param recipient The address which will receive the token0 and token1 amounts
    /// @param amount0 The amount of token0 to send
    /// @param amount1 The amount of token1 to send
    /// @param data Any data to be passed through to the callback
  function flash(
    address recipient,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
  ) external;
}
