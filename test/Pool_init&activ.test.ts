// TO DO
// the tests must be refactored
// there is a strange behaviour:
// the test cases are given by const arrays: fees, toInitialize, supplyFromInit
// it happens that the same test case may pass or be failed depending on the set of all tests <--- bug to be found
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import { contractNames } from '../scripts/consts';
import { deployContract } from '../scripts/utils';
import { DesireSwapV0Factory, DesireSwapV0Pool, IDesireSwapV0Factory, PoolDeployer, SwapRouter, TestERC20 } from '../typechain';

const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000';
const E18 = BigNumber.from(10).pow(18);
const E14 = BigNumber.from(10).pow(14);
const fees = [BigNumber.from(4).mul(E14), BigNumber.from(5).mul(E14), BigNumber.from(30).mul(E14), BigNumber.from(100).mul(E14)];
const sqrtRangeMultipliers = [BigNumber.from('1000049998750062496'), BigNumber.from('1000500100010000494'), BigNumber.from('1002503002301265502'), BigNumber.from('1010049662092876444')];

describe('Pool Tests', async function () {
  let deployer: PoolDeployer;
  let factory: IDesireSwapV0Factory;
  let swapRouter: SwapRouter;
  let tokenA: TestERC20;
  let tokenB: TestERC20;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let poolAddress: string;
  let pool: DesireSwapV0Pool;
  let Pool: any;
  let got: any;

  const activate = [1, 200, 400];
  const initArguments = [-1000, -100, 0, 100, 1000];
  const initSqrtMultiplier = [
    ['951231802418720714', '995012727929250863', '1000000000000000000', '1005012269623051144', '1051268468376765990'],
    ['606545822157838008', '951231802418721635', '1000000000000000000', '1051268468376765912', '1648680055931165216'],
    ['82095259205968929', '778810517493079476', '1000000000000000000', '1284009367540270688', '12180971345630275339'],
    ['45422633889282', '367897834377128226', '1000000000000000000', '2718145926825191179', '22015456048549476138200'],
  ];

  for (let poolType = 0; poolType < fees.length; poolType++) {
    describe('Testing PoolType[' + poolType + ']', async function () {
      describe('Testing Initialization', async function () {
        beforeEach(async () => {
          [owner, user1, user2, user3] = await ethers.getSigners();
          deployer = await deployContract<PoolDeployer>(contractNames.poolDeployer);
          factory = await deployContract<DesireSwapV0Factory>(contractNames.factory, owner.address, deployer.address);
          swapRouter = await deployContract<SwapRouter>(contractNames.swapRouter, factory.address, ADDRESS_ZERO);
          Pool = await ethers.getContractFactory('DesireSwapV0Pool');
          await factory.connect(owner).setSwapRouter(swapRouter.address);
          tokenA = await deployContract<TestERC20>(contractNames.token, 'token A', 'tA', owner.address);
          tokenB = await deployContract<TestERC20>(contractNames.token, 'token B', 'tB', owner.address);
          await factory.connect(owner).createPool(tokenA.address, tokenB.address, fees[poolType], 'DSV0P: token A/tokenB pair', 'DSP tA-tB ()');
          poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fees[poolType]);
          pool = Pool.attach(poolAddress);
        });

        it('should fail while initialized not by the owner', async function () {
          await expect(pool.connect(user1).initialize('0')).to.be.reverted;
        });

        for (let init = 0; init < initArguments.length; init++) {
          it('should initialize correct range with correct sqrtPriceBottom for init = ' + init, async function () {
            //Arrange
            //Act
            await pool.connect(owner).initialize(initArguments[init]);
            got = await pool.getFullRangeInfo(initArguments[init]);
            let { 0: reserve0, 1: reserve1, 2: sqrt0, 3: sqrt1, 4: supCoef, 5: active } = got;
            //Assert
            expect(await pool.initialized()).to.equal(true);
            expect(await pool.lowestActivatedRange()).to.equal(initArguments[init]);
            expect(await pool.highestActivatedRange()).to.equal(initArguments[init]);
            expect((await pool.sqrtRangeMultiplier()).toString()).to.equal(sqrtRangeMultipliers[poolType]);
            expect(reserve0.toString()).to.equal('0');
            expect(reserve1.toString()).to.equal('0');
            expect(sqrt0.toString()).to.equal(initSqrtMultiplier[poolType][init]);
            expect(sqrt1.toString()).to.equal(sqrt0.mul(BigNumber.from(sqrtRangeMultipliers[poolType])).div(E18));
            expect(supCoef.toString()).to.equal('0');
            expect(active).to.equal(true);
          });
        }
      });

      describe('Testing activation', async function () {
        beforeEach(async () => {
          [owner, user1, user2, user3] = await ethers.getSigners();
          deployer = await deployContract<PoolDeployer>(contractNames.poolDeployer);
          factory = await deployContract<DesireSwapV0Factory>(contractNames.factory, owner.address, deployer.address);
          swapRouter = await deployContract<SwapRouter>(contractNames.swapRouter, factory.address, ADDRESS_ZERO);
          Pool = await ethers.getContractFactory('DesireSwapV0Pool');
          await factory.connect(owner).setSwapRouter(swapRouter.address);
          tokenA = await deployContract<TestERC20>(contractNames.token, 'token A', 'tA', owner.address);
          tokenB = await deployContract<TestERC20>(contractNames.token, 'token B', 'tB', owner.address);
          await factory.connect(owner).createPool(tokenA.address, tokenB.address, fees[poolType], 'DSV0P: token A/tokenB pair', 'DSP tA-tB ()');
          poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fees[poolType]);
          pool = Pool.attach(poolAddress);
        });

        for (let init = 0; init < initArguments.length; init++) {
          it('should fail for already activated', async function () {
            //Act
            await pool.connect(owner).initialize(initArguments[init]);
            //Assert
            await expect(pool.activate(initArguments[init])).to.be.reverted;
          });
          for (let act = 0; act < activate.length; act++)
            it('activision should work correctly', async function () {
              //Arrange
              await pool.connect(owner).initialize(initArguments[init]);
              //Act
              await pool.activate(initArguments[init] + activate[act]);
              //Assert
              expect(await pool.highestActivatedRange()).to.equal(initArguments[init] + activate[act]);
              expect(await pool.lowestActivatedRange()).to.equal(initArguments[init]);

              await pool.activate(initArguments[init] - activate[act]);
              expect(await pool.highestActivatedRange()).to.equal(initArguments[init] + activate[act]);
              expect(await pool.lowestActivatedRange()).to.equal(initArguments[init] - activate[act]);
            });
        }
      });
    });
  }
});
