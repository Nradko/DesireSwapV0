// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import './interfaces/IDesireSwapV0Factory.sol';
import './interfaces/IDesireSwapV0Pool.sol';

import './base/PeripheryPayments.sol';
import './base/PeripheryImmutableState.sol';
import './base/PeripheryValidation.sol';

import './interfaces/ILiquidityManager.sol';

import './libraries/CallbackValidation.sol';
import 'hardhat/console.sol';

contract LiquidityManager is ILiquidityManager, PeripheryImmutableState, PeripheryPayments, PeripheryValidation {
  constructor(address _factory, address _WETH9) PeripheryImmutableState(_factory, _WETH9) {}


  ///////////
  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
  ///////////


  struct MintCallbackData {
    PoolAddress.PoolKey poolKey;
    address payer;
  }

  function desireSwapV0MintCallback(
    uint256 amount0Owed,
    uint256 amount1Owed,
    bytes calldata data
  ) external override {
    MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
    CallbackValidation.verifyCallback(factory, decoded.poolKey);
    require(decoded.payer == tx.origin);
    if (amount0Owed > 0) pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
    if (amount1Owed > 0) pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
  }

  // inherit doc from ILiquidityManager
  function supply(SupplyParams calldata params)
    external
    payable
    override
    checkDeadline(params.deadline)
    returns (
      address poolAddress,
      uint256 ticketId,
      uint256 amount0,
      uint256 amount1
    )
  {
    require(params.liqToAdd > 0, 'DSV0LM(supply): liquidity=0');
    PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(params.token0, params.token1, params.fee);
    poolAddress = PoolAddress.computeAddress(factory, poolKey);
    require(poolAddress != address(0), 'DSV0LM(supply): pool=0');
    IDesireSwapV0Pool pool = IDesireSwapV0Pool(poolAddress);
    (ticketId, amount0, amount1) = pool.mint(params.recipient, params.lowestRangeIndex, params.highestRangeIndex, params.liqToAdd, abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender})));
    require(amount0 <= params.amount0Max, uint2str(amount0));
    require(amount1 <= params.amount1Max, uint2str(amount1));
    ticketId = pool.getNextTicketId() - 1;
    emit Supply(params.recipient, poolAddress, ticketId);
  }
}
