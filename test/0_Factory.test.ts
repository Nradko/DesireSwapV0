// TO DO
// the tests must be refactored
// there is a strange behaviour:
// the test cases are given by const arrays: fees, toInitialize, supplyFromInit
// it happens that the same test case may pass or be failed depending on the set of all tests <--- bug to be found
import { DesireSwapV0Factory, TestERC20, PoolDeployer, IDesireSwapV0Factory } from '../typechain';
import { contractNames } from '../scripts/consts';
import { deployContract } from '../scripts/utils';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import 'mocha';

import { BigNumber } from '@ethersproject/bignumber';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000';
const E14 = BigNumber.from(10).pow(14);
const fees = [BigNumber.from(400), BigNumber.from(500), BigNumber.from(3000), BigNumber.from(10000)];
const ticksInRange = [1, 10, 50, 200];
const sqrtRangeMultipliers = [BigNumber.from('1000049998750062496'), BigNumber.from('1000500100010000494'), BigNumber.from('1002503002301265502'), BigNumber.from('1010049662092876444')];
const sqrtRangeMultipliers100 = [BigNumber.from('1005012269623051144'), BigNumber.from('1051268468376765912'), BigNumber.from('1284009367540270688'), BigNumber.from('2718145926825191179')];

describe('0_Factory testing', async function () {
  let deployer: PoolDeployer;
  let factory: IDesireSwapV0Factory;
  let tokenA: TestERC20;
  let tokenB: TestERC20;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let swapRouter: SignerWithAddress;
  let poolAddress: string;

  beforeEach(async () => {
    deployer = await deployContract<PoolDeployer>(contractNames.poolDeployer);
    const [etherUser, etherUser1, etherUser2, etherUser3] = await ethers.getSigners();
    owner = etherUser;
    user1 = etherUser1;
    user2 = etherUser2;
    swapRouter = etherUser3;
    factory = await deployContract<DesireSwapV0Factory>(contractNames.factory, owner.address, deployer.address);
    tokenA = await deployContract<TestERC20>(contractNames.token, 'token A', 'tA', owner.address);
    tokenB = await deployContract<TestERC20>(contractNames.token, 'token B', 'tB', owner.address);
  });

  describe('Deployment tests', function () {
    it('Should have deployed with right owner', async function () {
      expect(await factory.owner()).to.equal(owner.address);
    });

    it('Should have deployed with right feeCollector', async function () {
      expect(await factory.feeCollector()).to.equal(owner.address);
    });

    it('Shouldhave  deployed with right deployer address', async function () {
      expect(await factory.deployerAddress()).to.equal(deployer.address);
    });

    it('Should have deployed with four right feeToTicksInRange entries', async function () {
      for (let step = 0; step < fees.length; step++) {
        expect(await factory.feeToTicksInRange(fees[step].toString())).to.equal(ticksInRange[step]);
      }
    });
  });

  describe('Modifying simple global variables', function () {
    it('setOwner should fail while beeing called by not the owner', async function () {
      await expect(factory.connect(user1).setOwner(user1.address)).to.be.reverted;
    });

    it('setOwner should work while called by the owner', async function () {
      await factory.connect(owner).setOwner(user2.address);
      expect(await factory.owner()).to.equal(user2.address);
    });

    it('setFeeCollector should fail while called by not the owner', async function () {
      await expect(factory.connect(user1).setFeeCollector(user1.address)).to.be.reverted;
    });

    it('setFeeCollector should work while called by the owner', async function () {
      //Arrange
      await factory.connect(owner).setOwner(user2.address);
      //Act
      await factory.connect(user2).setFeeCollector(user2.address);
      //Assert
      expect(await factory.feeCollector()).to.equal(user2.address);
    });

    it('setSwapRouter should work while called by the owner', async function () {
      await factory.connect(owner).setSwapRouter(swapRouter.address);
      expect(await factory.swapRouter()).to.equal(swapRouter.address);
    });
  });

  describe('Pools managment', function () {
    it('addPoolType should fail while called by not the onwer', async function () {
      await expect(factory.connect(user1).addPoolType('1000', '1000')).to.be.reverted;
    });

    it('addPoolType should fail for alrady existing fee', async function () {
      await expect(factory.connect(owner).addPoolType(fees[0], '1000')).to.be.reverted;
    });

    it('addPoolType should work while called properly', async function () {
      await factory.connect(owner).addPoolType('3333', '33333');
      expect(await factory.feeToTicksInRange('3333')).to.equal(BigNumber.from('33333'));
    });

    it('createPool should fail while called by not the owner', async function () {
      await expect(factory.connect(user1).createPool(tokenA.address, tokenB.address, fees[0], 'DesireSwap Pool: tokenA-tokenB', 'DSP: tA-tB')).to.be.reverted;
    });
    it('createPool should fail while called with tokenA=tokebB', async function () {
      await expect(factory.connect(owner).createPool(tokenA.address, tokenA.address, fees[0], 'DesireSwap Pool: tokenA-tokenB', 'DSP: tA-tB')).to.be.reverted;
    });
    it('createPool should fail while called with tokenA= address(0)', async function () {
      await expect(factory.connect(owner).createPool(ADDRESS_ZERO, tokenB.address, fees[0], 'DesireSwap Pool: tokenA-tokenB', 'DSP: tA-tB')).to.be.reverted;
    });
    it('createPool should fail while called with tokenB= address(0)', async function () {
      await expect(factory.connect(owner).createPool(tokenA.address, ADDRESS_ZERO, fees[0], 'DesireSwap Pool: tokenA-tokenB', 'DSP: tA-tB')).to.be.reverted;
    });
    for (let step = 0; step < fees.length; step++) {
      it('createPool should work properly for correct arguments' + step.toString(), async function () {
        //Arrange
        await factory.connect(owner).setSwapRouter(swapRouter.address);
        //Act
        await factory.connect(owner).createPool(tokenA.address, tokenB.address, fees[step], 'DesireSwap Pool: tokenA-tokenB', 'DSP: tA-tB');
        poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fees[step]);
        const Pool = await ethers.getContractFactory('DesireSwapV0Pool');
        const pool = await Pool.attach(poolAddress);
        //Assert
        expect(await factory.poolAddress(tokenA.address, tokenB.address, fees[step])).to.equal(poolAddress);
        expect(await factory.poolAddress(tokenB.address, tokenA.address, fees[step])).to.equal(poolAddress);
        expect(await pool.token0()).to.equal(tokenA.address < tokenB.address ? tokenA.address : tokenB.address);
        expect(await pool.token1()).to.equal(tokenA.address > tokenB.address ? tokenA.address : tokenB.address);
        expect(await pool.factory()).to.equal(factory.address);
        expect(await pool.swapRouter()).to.equal(swapRouter.address);
        expect(await pool.feePercentage()).to.equal(fees[step]);
        expect(await pool.sqrtRangeMultiplier()).to.equal(sqrtRangeMultipliers[step]);
        expect(await pool.sqrtRangeMultiplier100()).to.equal(sqrtRangeMultipliers100[step]);
        expect(await pool.protocolFeePart()).to.equal(BigNumber.from(2).mul(BigNumber.from(10).pow(5)));
        expect(await pool.initialized()).to.equal(false);
        expect(await pool.protocolFeeIsOn()).to.equal(true);
      });
    }
  });
});
