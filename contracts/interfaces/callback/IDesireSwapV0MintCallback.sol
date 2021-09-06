// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


interface IDesireSwapV0MintCallback {

    function desireSwapV0MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}