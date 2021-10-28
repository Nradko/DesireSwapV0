// TO DO
// the tests must be refactored
// there is a strange behaviour:
// the test cases are given by const arrays: fees, toInitialize, supplyFromInit
// it happens that the same test case may pass or be failed depending on the set of all tests <--- bug to be found
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import { contractNames } from '../scripts/consts';
import { deployContract } from '../scripts/utils';
import { DesireSwapV0Factory, DesireSwapV0Pool, IDesireSwapV0Factory, LiquidityManager, PoolDeployer, SwapRouter, TestERC20 } from '../typechain';

const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000';
const MAX_UINT = '57896044618658097711785492504343953926634992332820282019728792003956564819967'; //Max Int
const E6 = BigNumber.from(10).pow(6);
const E14 = BigNumber.from(10).pow(14);
const E18 = BigNumber.from(10).pow(18);
const fees = [BigNumber.from(400), BigNumber.from(500), BigNumber.from(3000)];
const usersTokensAmount = E18.pow(2);
const protocolFee = BigNumber.from(200000); //1E6

const toInitialize = [-974];
const supplyFromInit = [3];
for (let poolType = 0; poolType < fees.length; poolType++) {
  for (let init = 0; init < toInitialize.length; init++) {
    for (let sup = 0; sup < supplyFromInit.length; sup++) {
      describe('4_PoolTest', async function () {
        this.timeout(0);
        const lowestIndex = toInitialize[init] - supplyFromInit[sup];
        const highestIndex = toInitialize[init] + supplyFromInit[sup];
        let deployer: PoolDeployer;
        let factory: IDesireSwapV0Factory;
        let swapRouter: SwapRouter;
        let liqManager: LiquidityManager;
        let tokenA: TestERC20;
        let tokenB: TestERC20;
        let token0: TestERC20;
        let token1: TestERC20;
        let owner: SignerWithAddress;
        let user1: SignerWithAddress;
        let user2: SignerWithAddress;
        let user3: SignerWithAddress;
        let poolAddress: string;
        let pool: DesireSwapV0Pool;
        let Pool: any;
        let users: SignerWithAddress[];

        beforeEach(async () => {
          [owner, user1, user2, user3] = await ethers.getSigners();
          users = [owner, user1, user2, user3];
          deployer = await deployContract<PoolDeployer>(contractNames.poolDeployer);
          factory = await deployContract<DesireSwapV0Factory>(contractNames.factory, owner.address, deployer.address);
          swapRouter = await deployContract<SwapRouter>(contractNames.swapRouter, factory.address, ADDRESS_ZERO);
          liqManager = await deployContract<LiquidityManager>(contractNames.liquidityManager, factory.address, ADDRESS_ZERO);
          Pool = await ethers.getContractFactory('DesireSwapV0Pool');
          await factory.connect(owner).setSwapRouter(swapRouter.address);
          tokenA = await deployContract<TestERC20>(contractNames.token, 'token A', 'tA', owner.address);
          tokenB = await deployContract<TestERC20>(contractNames.token, 'token B', 'tB', owner.address);
          for (let i = 1; i < users.length; i++) {
            await tokenA.connect(owner).transfer(users[i].address, usersTokensAmount);
            await tokenB.connect(owner).transfer(users[i].address, usersTokensAmount);
            await tokenA.connect(users[i]).approve(liqManager.address, MAX_UINT);
            await tokenB.connect(users[i]).approve(liqManager.address, MAX_UINT);
          }
          for (let i = 0; i < users.length; i++) {
            await tokenA.connect(users[i]).approve(swapRouter.address, MAX_UINT);
            await tokenB.connect(users[i]).approve(swapRouter.address, MAX_UINT);
          }
          await factory.connect(owner).createPool(tokenA.address, tokenB.address, fees[poolType], 'DSV0P: token A/tokenB pair', 'DSP tA-tB ()');
          poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fees[poolType]);
          pool = Pool.attach(poolAddress);
          token0 = tokenA.address < tokenB.address ? tokenA : tokenB;
          token1 = tokenA.address > tokenB.address ? tokenA : tokenB;
          console.log('tu0');
          await pool.connect(owner).initialize(toInitialize[init]);
          await pool.connect(owner).activate(toInitialize[init] - supplyFromInit[sup] - 1);
          await pool.connect(owner).activate(toInitialize[init] + supplyFromInit[sup] + 1);
        });
        describe('Pool Test \n Fee test: \n poolType =' + poolType + '\ntoInitialize =' + toInitialize[init] + '\nsupplyFromInit = ' + supplyFromInit[sup], async function () {
          it('accumulation in token1', async function () {
            //Arrange
            const feeEarning = E6.add(fees[poolType].mul(E6.sub(protocolFee)).div(E6).mul(2)); // we are doing two swaps => .mul(2)
            await liqManager.connect(user1).supply({
              token0: token0.address,
              token1: token1.address,
              fee: fees[poolType],
              lowestRangeIndex: toInitialize[init],
              highestRangeIndex: toInitialize[init],
              liqToAdd: E14,
              amount0Max: MAX_UINT,
              amount1Max: MAX_UINT,
              recipient: user1.address,
              deadline: MAX_UINT,
            });
            await liqManager.connect(user1).supply({
              token0: token0.address,
              token1: token1.address,
              fee: fees[poolType],
              lowestRangeIndex: toInitialize[init] - supplyFromInit[sup],
              highestRangeIndex: toInitialize[init] + supplyFromInit[sup],
              liqToAdd: E14.mul(E14),
              amount0Max: MAX_UINT,
              amount1Max: MAX_UINT,
              recipient: user1.address,
              deadline: MAX_UINT,
            });
            const totalSupplied = await pool.getTotalReserves();
            let totalResrves = totalSupplied;
            console.log(totalResrves[0].toString());
            //Act
            await swapRouter.connect(user2).exactOutputSingle({
              tokenIn: token0.address,
              tokenOut: token1.address,
              fee: fees[poolType],
              recipient: user2.address,
              deadline: MAX_UINT,
              amountOut: totalResrves[1].toString(),
              amountInMaximum: MAX_UINT,
              sqrtPriceLimitX96: '0',
            });

            totalResrves = await pool.getTotalReserves();
            const amountOut = totalResrves[0].sub(totalSupplied[0]).toString();
            console.log('tu2');
            console.log(amountOut);
            await swapRouter.connect(user2).exactOutputSingle({
              tokenIn: token1.address,
              tokenOut: token0.address,
              fee: fees[poolType],
              recipient: user2.address,
              deadline: MAX_UINT,
              amountOut: amountOut,
              amountInMaximum: MAX_UINT,
              sqrtPriceLimitX96: '0',
            });
            totalResrves = await pool.getTotalReserves();
            //Assert
            expect(totalResrves[0]).to.equal(totalSupplied[0]);
            expect(totalResrves[1].gte(totalSupplied[1].mul(feeEarning).div(E6))).to.be.true;
          });
        });
        describe('Fee test: \n poolType =' + poolType + '\ntoInitialize =' + toInitialize[init] + '\nsupplyFromInit = ' + supplyFromInit[sup], async function () {
          it('accumulation in token0', async function () {
            //Arrange
            this.timeout(0);
            const feeEarning = E6.add(fees[poolType].mul(E6.sub(protocolFee)).div(E6).mul(2)); // we are doing two swaps => .mul(2)
            await liqManager.connect(user1).supply({
              token0: token0.address,
              token1: token1.address,
              fee: fees[poolType],
              lowestRangeIndex: toInitialize[init],
              highestRangeIndex: toInitialize[init],
              liqToAdd: E14,
              amount0Max: MAX_UINT,
              amount1Max: MAX_UINT,
              recipient: user1.address,
              deadline: MAX_UINT,
            });
            await liqManager.connect(user1).supply({
              token0: token0.address,
              token1: token1.address,
              fee: fees[poolType],
              lowestRangeIndex: toInitialize[init] - supplyFromInit[sup],
              highestRangeIndex: toInitialize[init] + supplyFromInit[sup],
              liqToAdd: E14.mul(E14),
              amount0Max: MAX_UINT,
              amount1Max: MAX_UINT,
              recipient: user1.address,
              deadline: MAX_UINT,
            });
            const totalSupplied = await pool.getTotalReserves();
            let totalResrves = totalSupplied;
            //Act
            await swapRouter.connect(user2).exactOutputSingle({
              tokenIn: token1.address,
              tokenOut: token0.address,
              fee: fees[poolType],
              recipient: user2.address,
              deadline: MAX_UINT,
              amountOut: totalResrves[0].toString(),
              amountInMaximum: MAX_UINT,
              sqrtPriceLimitX96: '0',
            });
            totalResrves = await pool.getTotalReserves();
            const amountOut = totalResrves[1].sub(totalSupplied[1]).toString();
            //Act
            await swapRouter.connect(user2).exactOutputSingle({
              tokenIn: token0.address,
              tokenOut: token1.address,
              fee: fees[poolType],
              recipient: user2.address,
              deadline: MAX_UINT,
              amountOut: amountOut,
              amountInMaximum: MAX_UINT,
              sqrtPriceLimitX96: '0',
            });
            totalResrves = await pool.getTotalReserves();
            //Assert
            expect(totalResrves[1]).to.equal(totalSupplied[1]);
            expect(totalResrves[0].gte(totalSupplied[0].mul(feeEarning).div(E6))).to.be.true;
          });
        });
      });
    }
  }
}
