// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './pool/ITicket.sol';
import './pool/IDesireSwapV0PoolEvents.sol';
import './pool/IDesireSwapV0PoolImmutables.sol';
import './pool/IDesireSwapV0PoolView.sol';
import './pool/IDesireSwapV0PoolActions.sol';
import './pool/IDesireSwapV0PoolOwnerActions.sol';

interface IDesireSwapV0Pool is ITicket, IDesireSwapV0PoolEvents, IDesireSwapV0PoolImmutables, IDesireSwapV0PoolView, IDesireSwapV0PoolActions, IDesireSwapV0PoolOwnerActions {}
