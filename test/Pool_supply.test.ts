import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import { Contract } from 'hardhat/internal/hardhat-network/stack-traces/model';
import { contractNames } from '../scripts/consts';
import { deployContract } from '../scripts/utils';
import { DesireSwapV0Factory, IDesireSwapV0Pool, PoolDeployer, SwapRouter, TestERC20 } from '../typechain';

const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000';
const e14 = BigNumber.from(10).pow(14);
const e18 = BigNumber.from(10).pow(18);
const fees = [BigNumber.from(4).mul(e14), BigNumber.from(5).mul(e14), BigNumber.from(30).mul(e14), BigNumber.from(100).mul(e14)];
