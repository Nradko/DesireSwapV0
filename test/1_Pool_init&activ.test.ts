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
const fees = [BigNumber.from(400), BigNumber.from(500), BigNumber.from(3000), BigNumber.from(10000)];
const sqrtRangeMultipliers = [BigNumber.from('1000049998750062496'), BigNumber.from('1000500100010000494'), BigNumber.from('1002503002301265502'), BigNumber.from('1010049662092876444')];

describe('1_Pool Tests', async function () {
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

  const activate = [1];
  const initArguments = [
    [-9999, -999, 1, 999, 9999],
    [-39999, -999, 1, 999, 39999],
    [-5999, -999, 1, 999, 5999],
    [-2299, -999, 1, 999, 2299],
  ];
  const initSqrtMultiplier = [
    ['606576148690794945', '951279362819861346', '1000049998750062496', '1051215908895275393', '1648597628110404459'],
    ['2064246491', '606849155729564901', '1000500100010000494', '1647855963147515697', '484438037558180983984204397'],
    ['306898066443', '82300743828684458', '1002503002301265502', '12150558469818655752', '3258410882003457245647260'],
    ['103769287', '45879116011238', '1010049662092876444', '21796409498254055183735', '9636757948696574133278733528'],
  ];

  for (let poolType = 0; poolType < fees.length; poolType++) {
    describe('Testing PoolType[' + poolType + ']', async function () {
      this.timeout(0);
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

        for (let init = 0; init < initArguments[1].length; init++) {
          it('should initialize correct range with correct sqrtPriceBottom for init = ' + init, async function () {
            //Arrange
            //Act
            await pool.connect(owner).initialize(initArguments[poolType][init]);
            got = await pool.getFullRangeInfo(initArguments[poolType][init]);
            let { 0: reserve0, 1: reserve1, 2: sqrt0, 3: sqrt1, 4: supCoef, 5: active } = got;
            //Assert
            expect(await pool.initialized()).to.equal(true);
            expect(await pool.lowestActivatedRange()).to.equal(initArguments[poolType][init]);
            expect(await pool.highestActivatedRange()).to.equal(initArguments[poolType][init]);
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

        for (let init = 0; init < initArguments[1].length; init++) {
          it('should fail for already activated', async function () {
            //Act
            await pool.connect(owner).initialize(initArguments[poolType][init]);
            //Assert
            await expect(pool.activate(initArguments[poolType][init])).to.be.reverted;
          });
          for (let act = 0; act < activate.length; act++)
            it('activision should work correctly', async function () {
              //Arrange
              await pool.connect(owner).initialize(initArguments[poolType][init]);
              //Act
              await pool.activate(initArguments[poolType][init] + activate[act]);
              //Assert
              expect(await pool.highestActivatedRange()).to.equal(initArguments[poolType][init] + activate[act]);
              expect(await pool.lowestActivatedRange()).to.equal(initArguments[poolType][init]);

              await pool.activate(initArguments[poolType][init] - activate[act]);
              expect(await pool.highestActivatedRange()).to.equal(initArguments[poolType][init] + activate[act]);
              expect(await pool.lowestActivatedRange()).to.equal(initArguments[poolType][init] - activate[act]);
            });
        }
      });
    });
  }
});
