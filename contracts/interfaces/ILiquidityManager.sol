// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import './callback/IDesireSwapV0MintCallback.sol';

interface ILiquidityManager is IDesireSwapV0MintCallback
{
    event Supply(address indexed owner, uint256 positionId, address pool, uint256 ticketId);

    event Redeem(address indexed recipient, uint256 positionId, address pool, uint256 ticketId);

    ///@notice makes transfer to the pool while supplying liquidity
    ///@param amount0Owed amount of token0 to transfer from supplier to pool
    ///@param amount1Owed amount of token1 to transfer from supplier to pool
    ///@param data NO IDEA YET
    function desireSwapV0MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override;
    
    /// @notice Returns the position information associated with a given token ID.
    /// IMPORTANT tokenID is number stored in this contract while ticket ID is 
    /// number stored in Pool contract.
    /// @return owner of position
    /// @return pool that was supplied
    /// @return ticketId of position in the pool
    function positions(uint256 tokenID)
        external view
        returns (
        address owner,
        address pool,
        uint256 ticketId
        );

    struct SupplyParams {
        address token0;
        address token1;
        uint256 fee;
        int24 lowestRangeIndex;
        int24 highestRangeIndex;
        uint256 liqToAdd;
        uint256 amount0Max;
        uint256 amount1Max;
        address recipient;
        uint256 deadline;
    }

    struct SupplyReturns{
        uint256 positionId;
        uint256 ticketId;
        uint256 amount0;
        uint256 amount1;
        address poolAddress;
    }    

    function supply(SupplyParams calldata params)
    external payable
    returns (
        uint256 positionId,
        uint256 ticketId,
        uint256 amount0,
        uint256 amount1,
        address poolAddress
    );

    struct RedeemParams {
        uint256 positionId;
        address recipient;
        uint256 deadline;
    }

    /// @notice Redeems Liq from Pool and burns ticket
    /// @param params the params necessary to redeem
    /// @return amount0 The amount of token0 redeemed from pool
    /// @return amount1 The amount of token1 redeemed from pool
    function redeem(RedeemParams calldata params)
        external
        payable
        returns (
            uint256 amount0,
            uint256 amount1
        );



}