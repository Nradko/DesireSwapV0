// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


interface IDesireSwapV3FlashCallback {

    function desireSwapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}