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

function getRandomInt(max: number) {
  return Math.floor(Math.random() * max);
}

const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000';
const MAX_UINT = '115792089237316195423570985008687907853269984665640564039457584007913129639935';
const e9 = BigNumber.from(10).pow(9);
const E14 = BigNumber.from(10).pow(14);
const E18 = BigNumber.from(10).pow(18);
const fees = [BigNumber.from(4).mul(E14)]; //, BigNumber.from(5).mul(E14), BigNumber.from(30).mul(E14), BigNumber.from(100).mul(E14)];
const usersTokensAmount = E18.pow(2);

const toInitialize = [1000];
const supplyFromInit = [0];
for (let poolType = 0; poolType < fees.length; poolType++) {
  for (let init = 0; init < toInitialize.length; init++) {
    for (let sup = 0; sup < supplyFromInit.length; sup++) {
      const lowestIndex = toInitialize[init] - supplyFromInit[sup];
      const highestIndex = toInitialize[init] + supplyFromInit[sup];
      describe('Pool Tests: \npoolType: ' + poolType + '\ntoInitialize ->' + toInitialize[init] + '\nsupplyFromInit ->' + supplyFromInit[sup], async function () {
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

          await pool.connect(owner).initialize(toInitialize[init]);
          await pool.connect(owner).activate(toInitialize[init] - supplyFromInit[sup] - 1);
          await pool.connect(owner).activate(toInitialize[init] + supplyFromInit[sup] + 1);
          await tokenA.connect(owner).approve(liqManager.address, MAX_UINT);
          await tokenB.connect(owner).approve(liqManager.address, MAX_UINT);
          await liqManager.connect(owner).supply({
            token0: token0.address,
            token1: token1.address,
            fee: fees[poolType],
            lowestRangeIndex: toInitialize[init],
            highestRangeIndex: toInitialize[init],
            liqToAdd: E14,
            amount0Max: MAX_UINT,
            amount1Max: MAX_UINT,
            recipient: owner.address,
            deadline: MAX_UINT,
          });

          await liqManager.connect(owner).supply({
            token0: token0.address,
            token1: token1.address,
            fee: fees[poolType],
            lowestRangeIndex: toInitialize[init] - supplyFromInit[sup],
            highestRangeIndex: toInitialize[init] + supplyFromInit[sup],
            liqToAdd: e9.mul(E18),
            amount0Max: MAX_UINT,
            amount1Max: MAX_UINT,
            recipient: owner.address,
            deadline: MAX_UINT,
          });
        });
        describe('swap tests', async function () {
          describe('exactOutputSingle test', async function () {
            it('should fail for wrong deadline', async function () {
              //Act && Assert
              await expect(
                swapRouter.connect(owner).exactOutputSingle({
                  tokenIn: token1.address,
                  tokenOut: token0.address,
                  fee: fees[poolType],
                  recipient: owner.address,
                  deadline: '1',
                  amountOut: '1000',
                  amountInMaximum: MAX_UINT,
                  sqrtPriceLimitX96: '0',
                })
              ).to.be.reverted;
            });

            it('should fail when swapping more then totalReserve0', async function () {
              //Arrange
              const totalReserves = await pool.getTotalReserves();
              //Act && Assert
              await expect(
                swapRouter.connect(owner).exactOutputSingle({
                  tokenIn: token1.address,
                  tokenOut: token0.address,
                  fee: fees[poolType],
                  recipient: owner.address,
                  deadline: MAX_UINT,
                  amountOut: totalReserves[0].add(1).toString(),
                  amountInMaximum: MAX_UINT,
                  sqrtPriceLimitX96: '0',
                })
              ).to.be.reverted;
            });

            it('should fail when swapping more then totalReserve1', async function () {
              //Arrange
              const totalReserves = await pool.getTotalReserves();
              //Act && Assert
              await expect(
                swapRouter.connect(owner).exactOutputSingle({
                  tokenIn: token0.address,
                  tokenOut: token1.address,
                  fee: fees[poolType],
                  recipient: owner.address,
                  deadline: MAX_UINT,
                  amountOut: totalReserves[1].add(1).toString(),
                  amountInMaximum: MAX_UINT,
                  sqrtPriceLimitX96: '0',
                })
              ).to.be.reverted;
            });

            // the -1 below is important so the change of inUsePosition isn't triggered. Such
            it('should work for amountOut = totalReserve0', async function () {
              //Arrange
              const totalReserves = await pool.getTotalReserves();
              //Act && Assert
              await swapRouter.connect(owner).exactOutputSingle({
                tokenIn: token1.address,
                tokenOut: token0.address,
                fee: fees[poolType],
                recipient: owner.address,
                deadline: MAX_UINT,
                amountOut: totalReserves[0].toString(),
                amountInMaximum: MAX_UINT,
                sqrtPriceLimitX96: '0',
              });
            });

            it('should work for amountOut = totalReserve0', async function () {
              //Arrange
              const totalReserves = await pool.getTotalReserves();
              //Act && Assert
              await swapRouter.connect(owner).exactOutputSingle({
                tokenIn: token0.address,
                tokenOut: token1.address,
                fee: fees[poolType],
                recipient: owner.address,
                deadline: MAX_UINT,
                amountOut: totalReserves[1].toString(),
                amountInMaximum: MAX_UINT,
                sqrtPriceLimitX96: '0',
              });
            });

            it('should fail when amountInMaximum is exceeded', async function () {
              //Arrange
              const totalReserves = await pool.getTotalReserves();
              const amountOut: BigNumber = BigNumber.from(getRandomInt(1000000)).mul(totalReserves[1]).div(1000000);
              const amountIn: BigNumber = await swapRouter.callStatic.exactOutputSingle({
                tokenIn: token0.address,
                tokenOut: token1.address,
                fee: fees[poolType],
                recipient: owner.address,
                deadline: MAX_UINT,
                amountOut: amountOut.toString(),
                amountInMaximum: MAX_UINT,
                sqrtPriceLimitX96: '0',
              });
              // Act && Assert
              await expect(
                swapRouter.connect(user1).exactOutputSingle({
                  tokenIn: token0.address,
                  tokenOut: token1.address,
                  fee: fees[poolType],
                  recipient: user1.address,
                  deadline: MAX_UINT,
                  amountOut: amountOut.toString(),
                  amountInMaximum: amountIn.sub(1).toString(),
                  sqrtPriceLimitX96: '0',
                })
              ).to.be.reverted;
            });

            it('should fail when amountInMaximum is exceeded', async function () {
              //Arrange
              const totalReserves = await pool.getTotalReserves();
              const amountOut: BigNumber = BigNumber.from(getRandomInt(1000000)).mul(totalReserves[1]).div(1000000);
              const amountIn: BigNumber = await swapRouter.callStatic.exactOutputSingle({
                tokenIn: token1.address,
                tokenOut: token0.address,
                fee: fees[poolType],
                recipient: owner.address,
                deadline: MAX_UINT,
                amountOut: amountOut.toString(),
                amountInMaximum: MAX_UINT,
                sqrtPriceLimitX96: '0',
              });
              // Act && Assert
              await expect(
                swapRouter.connect(owner).exactOutputSingle({
                  tokenIn: token1.address,
                  tokenOut: token0.address,
                  fee: fees[poolType],
                  recipient: owner.address,
                  deadline: MAX_UINT,
                  amountOut: amountOut.toString(),
                  amountInMaximum: amountIn.sub(1).toString(),
                  sqrtPriceLimitX96: '0',
                })
              ).to.be.reverted;
            });
          });

          describe('exactInputSingle test', async function () {
            it('should fail for wrong deadline', async function () {
              await expect(
                swapRouter.connect(owner).exactInputSingle({
                  tokenIn: token1.address,
                  tokenOut: token0.address,
                  fee: fees[poolType],
                  recipient: owner.address,
                  deadline: '1',
                  amountIn: '1000',
                  amountOutMinimum: '0',
                  sqrtPriceLimitX96: '0',
                })
              ).to.be.reverted;
            });

            it('should fail when swapping more then totalReserve0', async function () {
              const totalReserves = await pool.getTotalReserves();
              //Act && Assert
              await expect(
                swapRouter.connect(owner).exactInputSingle({
                  tokenIn: token1.address,
                  tokenOut: token0.address,
                  fee: fees[poolType],
                  recipient: owner.address,
                  deadline: MAX_UINT,
                  amountIn: MAX_UINT,
                  amountOutMinimum: '0',
                  sqrtPriceLimitX96: '0',
                })
              ).to.be.reverted;
            });

            it('should fail when swapping more then totalReserve1', async function () {
              const totalReserves = await pool.getTotalReserves();
              //Act && Assert
              it('should fail for wrong deadline', async function () {
                await expect(
                  swapRouter.connect(owner).exactInputSingle({
                    tokenIn: token0.address,
                    tokenOut: token1.address,
                    fee: fees[poolType],
                    recipient: owner.address,
                    deadline: MAX_UINT,
                    amountIn: MAX_UINT,
                    amountOutMinimum: '0',
                    sqrtPriceLimitX96: '0',
                  })
                ).to.be.reverted;
              });
            });

            it('should work for sufficiently small amountIn', async function () {
              const totalReserves = await pool.getTotalReserves();
              //Act && Assert
              swapRouter.connect(owner).exactInputSingle({
                tokenIn: token0.address,
                tokenOut: token1.address,
                fee: fees[poolType],
                recipient: owner.address,
                deadline: MAX_UINT,
                amountIn: totalReserves[0].div(2).toString(),
                amountOutMinimum: '0',
                sqrtPriceLimitX96: '0',
              });
            });

            it('should work for sufficiently small amountIn', async function () {
              const totalReserves = await pool.getTotalReserves();
              //Act && Assert
              swapRouter.connect(owner).exactInputSingle({
                tokenIn: token1.address,
                tokenOut: token0.address,
                fee: fees[poolType],
                recipient: owner.address,
                deadline: MAX_UINT,
                amountIn: totalReserves[1].div(2).toString(),
                amountOutMinimum: '0',
                sqrtPriceLimitX96: '0',
              });
            });

            it('should fail when amountInMinimum is not exceeded', async function () {
              //Arrange
              const totalReserves = await pool.getTotalReserves();
              const amountIn: BigNumber = BigNumber.from(getRandomInt(1000000)).mul(totalReserves[1]).div(1000000);
              const amountOut: BigNumber = await swapRouter.callStatic.exactInputSingle({
                tokenIn: token1.address,
                tokenOut: token0.address,
                fee: fees[poolType],
                recipient: owner.address,
                deadline: MAX_UINT,
                amountIn: amountIn,
                amountOutMinimum: '0',
                sqrtPriceLimitX96: '0',
              });
              // Act && Assert
              await expect(
                swapRouter.connect(user1).exactInputSingle({
                  tokenIn: token1.address,
                  tokenOut: token0.address,
                  fee: fees[poolType],
                  recipient: user1.address,
                  deadline: MAX_UINT,
                  amountIn: amountIn,
                  amountOutMinimum: amountOut.add(1).toString(),
                  sqrtPriceLimitX96: '0',
                })
              ).to.be.reverted;
            });

            it('should fail when amountInMinimum is not exceeded', async function () {
              //Arrange
              const totalReserves = await pool.getTotalReserves();
              const amountIn: BigNumber = BigNumber.from(getRandomInt(1000000)).mul(totalReserves[0]).div(1000000);
              const amountOut: BigNumber = await swapRouter.callStatic.exactInputSingle({
                tokenIn: token0.address,
                tokenOut: token1.address,
                fee: fees[poolType],
                recipient: owner.address,
                deadline: MAX_UINT,
                amountIn: amountIn,
                amountOutMinimum: '0',
                sqrtPriceLimitX96: '0',
              });
              //Act && Assert
              await expect(
                swapRouter.connect(user1).exactInputSingle({
                  tokenIn: token0.address,
                  tokenOut: token1.address,
                  fee: fees[poolType],
                  recipient: user1.address,
                  deadline: MAX_UINT,
                  amountIn: amountIn,
                  amountOutMinimum: amountOut.add(1).toString(),
                  sqrtPriceLimitX96: '0',
                })
              ).to.be.reverted;
            });
          });
        });
      });
    }
  }
}
