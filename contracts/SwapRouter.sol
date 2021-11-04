// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import './base/PeripheryValidation.sol';
import './base/PeripheryImmutableState.sol';
import './base/PeripheryPayments.sol';
import './base/Multicall.sol';

import './interfaces/ISwapRouter.sol';

import './libraries/CallbackValidation.sol';
import './libraries/Path.sol';

contract SwapRouter is ISwapRouter, PeripheryImmutableState, PeripheryValidation, PeripheryPayments, Multicall {
  using Path for bytes;

  /// @dev Used as the placeholder value for amountInCached, because the computed amount in for an exact output swap
  /// can never actually be this value
  uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;

  /// @dev Transient storage variable used for returning the computed amount in for an exact output swap.
  uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;

  constructor(address _factory, address _WETH9) PeripheryImmutableState(_factory, _WETH9) {}

  /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
  function getPool(
    address tokenA,
    address tokenB,
    uint256 fee
  ) private view returns (IDesireSwapV0Pool) {
    return IDesireSwapV0Pool(IDesireSwapV0Factory(factory).poolAddress(tokenA, tokenB, fee));
  }

  struct SwapCallbackData {
    bytes path;
    address payer;
  }

  /// @inheritdoc IDesireSwapV0SwapCallback
  function desireSwapV0SwapCallback(
    int256 amount0Delta,
    int256 amount1Delta,
    bytes calldata _data
  ) external override {
    require(amount0Delta > 0 || amount1Delta > 0, 'SR(swapCallback): err'); // swaps entirely within 0-liquidity regions are not supported
    SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
    (address tokenIn, address tokenOut, uint256 fee) = data.path.decodeFirstPool();
    CallbackValidation.verifyCallback(factory, tokenIn, tokenOut, fee);
    (bool isExactInput, uint256 amountToPay) = amount0Delta > 0 ? (tokenIn < tokenOut, uint256(amount0Delta)) : (tokenOut < tokenIn, uint256(amount1Delta));
    if (isExactInput) {
      pay(tokenIn, data.payer, msg.sender, amountToPay);
    } else {
      // either initiate the next swap or pay
      if (data.path.hasMultiplePools()) {
        data.path = data.path.skipToken();
        exactOutputInternal(amountToPay, msg.sender, 0, data);
      } else {
        amountInCached = amountToPay;
        tokenIn = tokenOut; // swap in/out because exact output swaps are reversed
        pay(tokenIn, data.payer, msg.sender, amountToPay);
      }
    }
  }

  function exactInputInternal(
    uint256 amountIn,
    address recipient,
    uint256 sqrtPriceLimitX96,
    SwapCallbackData memory data
  ) private returns (uint256 amountOut) {
    // allow swapping to the router address with address 0
    if (recipient == address(0)) recipient = address(this);
    (address tokenIn, address tokenOut, uint256 fee) = data.path.decodeFirstPool();
    bool zeroForOne = tokenIn < tokenOut;
    (int256 amount0, int256 amount1) = getPool(tokenIn, tokenOut, fee).swap(recipient, zeroForOne, int256(amountIn), abi.encode(data));
    return uint256(-(zeroForOne ? amount1 : amount0));
  }

  /// @inheritdoc ISwapRouter
  function exactInputSingle(ExactInputSingleParams calldata params) external payable override checkDeadline(params.deadline) returns (uint256 amountOut) {
    require(!isContract(msg.sender), 'SR(eIS): contractCall');
    amountOut = exactInputInternal(
      params.amountIn,
      params.recipient,
      params.sqrtPriceLimitX96,
      SwapCallbackData({path: abi.encodePacked(params.tokenIn, params.fee, params.tokenOut), payer: msg.sender})
    );
    require(amountOut >= params.amountOutMinimum, 'SR(eIS):Too little received');
  }

  function exactInput(ExactInputParams memory params) external payable override checkDeadline(params.deadline) returns (uint256 amountOut) {
    address payer = msg.sender; // msg.sender pays for the first hop
    require(!isContract(payer), 'SR(eI): contractCall');

    while (true) {
      bool hasMultiplePools = params.path.hasMultiplePools();

      // the outputs of prior swaps become the inputs to subsequent ones
      params.amountIn = exactInputInternal(
        params.amountIn,
        hasMultiplePools ? address(this) : params.recipient, // for intermediate swaps, this contract custodies
        0,
        SwapCallbackData({
          path: params.path.getFirstPool(), // only the first pool in the path is necessary
          payer: payer
        })
      );

      // decide whether to continue or terminate
      if (hasMultiplePools) {
        payer = address(this); // at this point, the caller has paid
        params.path = params.path.skipToken();
      } else {
        amountOut = params.amountIn;
        break;
      }
    }

    require(amountOut >= params.amountOutMinimum, 'SR(eI):Too little received');
  }

  function exactOutputInternal(
    uint256 amountOut,
    address recipient,
    uint256 sqrtPriceLimitX96,
    SwapCallbackData memory data
  ) private returns (uint256 amountIn) {
    // allow swapping to the router address with address 0
    if (recipient == address(0)) recipient = address(this);

    (address tokenOut, address tokenIn, uint256 fee) = data.path.decodeFirstPool();

    bool zeroForOne = tokenIn < tokenOut;

    (int256 amount0Delta, int256 amount1Delta) = getPool(tokenIn, tokenOut, fee).swap(recipient, zeroForOne, -int256(amountOut), abi.encode(data));

    uint256 amountOutReceived;
    (amountIn, amountOutReceived) = zeroForOne ? (uint256(amount0Delta), uint256(-amount1Delta)) : (uint256(amount1Delta), uint256(-amount0Delta));
    // it's technically possible to not receive the full output amount,
    // so if no price limit has been specified, require this possibility away
    if (sqrtPriceLimitX96 == 0) require(amountOutReceived == amountOut, 'SR(eOI): err');
  }

  function exactOutputSingle(ExactOutputSingleParams calldata params) external payable override checkDeadline(params.deadline) returns (uint256 amountIn) {
    // avoid an SLOAD by using the swap return data
    require(!isContract(msg.sender), 'SR(eOS): contractCall');
    amountIn = exactOutputInternal(
      params.amountOut,
      params.recipient,
      params.sqrtPriceLimitX96,
      SwapCallbackData({path: abi.encodePacked(params.tokenOut, params.fee, params.tokenIn), payer: msg.sender})
    );

    require(amountIn <= params.amountInMaximum, 'SR(eOS): Too much requested');
    // has to be reset even though we don't use it in the single hop case
    amountInCached = DEFAULT_AMOUNT_IN_CACHED;
  }

  /// @inheritdoc ISwapRouter
  function exactOutput(ExactOutputParams calldata params) external payable override checkDeadline(params.deadline) returns (uint256 amountIn) {
    // it's okay that the payer is fixed to msg.sender here, as they're only paying for the "final" exact output
    // swap, which happens first, and subsequent swaps are paid for within nested callback frames
    require(!isContract(msg.sender), 'SR(eO): contractCall');
    exactOutputInternal(params.amountOut, params.recipient, 0, SwapCallbackData({path: params.path, payer: msg.sender}));

    amountIn = amountInCached;
    require(amountIn <= params.amountInMaximum, 'SR(eO):Too much requested');
    amountInCached = DEFAULT_AMOUNT_IN_CACHED;
  }

  function isContract(address account) internal view returns (bool) {
    // This method relies on extcodesize, which returns 0 for contracts in
    // construction, since the code is only stored at the end of the
    // constructor execution.

    uint256 size;
    assembly {
      size := extcodesize(account)
    }
    return size > 0;
  }
}
