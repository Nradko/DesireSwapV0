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
import { DesireSwapV0Factory, IDesireSwapV0Factory, DesireSwapV0Pool, LiquidityManager, PoolDeployer, SwapRouter, TestERC20 } from '../typechain';

function getRandomInt(max: number) {
  return Math.floor(Math.random() * max);
}

const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000';
const MAX_UINT = '115792089237316195423570985008687907853269984665640564039457584007913129639935';
const E14 = BigNumber.from(10).pow(14);
const E18 = BigNumber.from(10).pow(18);
const fees = [BigNumber.from(400)]; //, BigNumber.from(500), BigNumber.from(3000), BigNumber.from(10000)];
const usersTokensAmount = BigNumber.from('1000000000').mul(E18);

const toInitialize = [-1000]; //, 100];
const supplyfromInit = [0]; //, 30];
for (let init = 0; init < toInitialize.length; init++) {
  for (let poolType = 0; poolType < fees.length; poolType++) {
    describe('2_Pool Tests', async function () {
      this.timeout(0);
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
      let got: any;
      let users: SignerWithAddress[];
      let data = ['0', '0'];

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
          await tokenA.connect(users[i]).approve(liqManager.address, MAX_UINT);
          await tokenB.connect(users[i]).approve(liqManager.address, MAX_UINT);
        }
        await factory.connect(owner).createPool(tokenA.address, tokenB.address, fees[poolType], 'DSV0P: token A/tokenB pair', 'DSP tA-tB ()');
        poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fees[poolType]);
        pool = Pool.attach(poolAddress);
        token0 = tokenA.address < tokenB.address ? tokenA : tokenB;
        token1 = tokenA.address > tokenB.address ? tokenA : tokenB;

        await pool.connect(owner).initialize(toInitialize[init]);

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
      });
      for (let sup = 0; sup < supplyfromInit.length; sup++) {
        const lowestIndex = toInitialize[init] - supplyfromInit[sup];
        const highestIndex = toInitialize[init] + supplyfromInit[sup];

        describe('Supplying', async function () {
          it('should fail when deadline is to low', async function () {
            //Arrange
            const liqToAdd = BigNumber.from(getRandomInt(100000)).mul(E14);
            //Act && Assert
            await expect(
              liqManager.connect(user1).supply({
                token0: token0.address,
                token1: token1.address,
                fee: fees[poolType],
                lowestRangeIndex: lowestIndex,
                highestRangeIndex: highestIndex,
                liqToAdd: liqToAdd,
                amount0Max: MAX_UINT,
                amount1Max: MAX_UINT,
                recipient: user1.address,
                deadline: '1',
              })
            ).to.be.reverted;

            it('should fail when exceeds amount0Max', async function () {
              //Arrange
              const liqToAdd = BigNumber.from(getRandomInt(100000)).mul(E14);
              const callstaticData = await liqManager.callStatic.supply({
                token0: token0.address,
                token1: token1.address,
                fee: fees[poolType],
                lowestRangeIndex: lowestIndex,
                highestRangeIndex: highestIndex,
                liqToAdd: liqToAdd,
                amount0Max: MAX_UINT,
                amount1Max: MAX_UINT,
                recipient: owner.address,
                deadline: MAX_UINT,
              });
              const amounts: BigNumber[] = [callstaticData[2], callstaticData[3]];
              //Act && Assert
              await expect(
                liqManager.connect(user1).supply({
                  token0: token0.address,
                  token1: token1.address,
                  fee: fees[poolType],
                  lowestRangeIndex: lowestIndex,
                  highestRangeIndex: highestIndex,
                  liqToAdd: liqToAdd,
                  amount0Max: amounts[0].sub(1).toString(),
                  amount1Max: amounts[1].toString(),
                  recipient: user1.address,
                  deadline: MAX_UINT,
                })
              ).to.be.reverted;
            });

            it('should fail when exceeds amount1Max', async function () {
              //Arrange
              const liqToAdd = BigNumber.from(getRandomInt(100000)).mul(E14);
              const callstaticData = await liqManager.callStatic.supply({
                token0: token0.address,
                token1: token1.address,
                fee: fees[poolType],
                lowestRangeIndex: lowestIndex,
                highestRangeIndex: highestIndex,
                liqToAdd: liqToAdd,
                amount0Max: MAX_UINT,
                amount1Max: MAX_UINT,
                recipient: owner.address,
                deadline: MAX_UINT,
              });
              const amounts: BigNumber[] = [callstaticData[2], callstaticData[3]];
              //Act && Assert
              await expect(
                liqManager.connect(user1).supply({
                  token0: token0.address,
                  token1: token1.address,
                  fee: fees[poolType],
                  lowestRangeIndex: lowestIndex,
                  highestRangeIndex: highestIndex,
                  liqToAdd: liqToAdd,
                  amount0Max: amounts[0].toString(),
                  amount1Max: amounts[1].sub(1).toString(),
                  recipient: user1.address,
                  deadline: MAX_UINT,
                })
              ).to.be.reverted;
            });

            it('should work for correct data', async function () {
              //Arrange
              const liqToAdd = BigNumber.from(getRandomInt(100000)).mul(E14);
              const totalReservesBefore = await pool.getTotalReserves();
              const balance0Before = await token0.balanceOf(pool.address);
              const balance1Before = await token1.balanceOf(pool.address);
              const callstaticData = await liqManager.callStatic.supply({
                token0: token0.address,
                token1: token1.address,
                fee: fees[poolType],
                lowestRangeIndex: lowestIndex,
                highestRangeIndex: highestIndex,
                liqToAdd: liqToAdd,
                amount0Max: MAX_UINT,
                amount1Max: MAX_UINT,
                recipient: owner.address,
                deadline: MAX_UINT,
              });
              const amounts: BigNumber[] = [callstaticData[2], callstaticData[3]];
              const ticketId: BigNumber = callstaticData[1];
              //Act
              await liqManager.connect(user1).supply({
                token0: token0.address,
                token1: token1.address,
                fee: fees[poolType],
                lowestRangeIndex: lowestIndex,
                highestRangeIndex: highestIndex,
                liqToAdd: liqToAdd,
                amount0Max: amounts[0].toString(),
                amount1Max: amounts[1].toString(),
                recipient: user1.address,
                deadline: MAX_UINT,
              });

              const totalReservesAfter = await pool.getTotalReserves();
              const balance0After = await token0.balanceOf(pool.address);
              const balance1After = await token1.balanceOf(pool.address);
              const ticketData = await pool.getTicketData(ticketId);
              //Assert
              expect(balance0After).to.equal(balance0Before.add(amounts[0]));
              expect(balance1After).to.equal(balance1Before.add(amounts[1]));
              expect(totalReservesAfter[0]).to.equal(totalReservesBefore[0].add(amounts[0]));
              expect(totalReservesAfter[1]).to.equal(totalReservesBefore[1].add(amounts[1]));

              expect((await pool.getNextTicketId()).toString()).to.equal('3');
              expect(await pool.ownerOf(ticketId)).to.equal(user1.address);
              expect(ticketData[0]).to.equal(lowestIndex);
              expect(ticketData[1]).to.equal(highestIndex);
              expect(ticketData[2].toString()).to.equal(liqToAdd);
            });
          });

          describe('Supplying and then burning should result in having more or less the same funds (accepted loss < 1/100000)', async function () {
            it('one supply and one burn', async function () {
              //Arrange
              const ACCEPTED_LOSS = BigNumber.from(100000); //denominator of 1/denominator
              const liqToAdd = BigNumber.from(getRandomInt(100000)).mul(E14);
              const userBalancesBefore: BigNumber[] = [await token0.balanceOf(pool.address), await token1.balanceOf(pool.address)];
              const callstaticData = await liqManager.callStatic.supply({
                token0: token0.address,
                token1: token1.address,
                fee: fees[poolType],
                lowestRangeIndex: lowestIndex,
                highestRangeIndex: highestIndex,
                liqToAdd: liqToAdd,
                amount0Max: MAX_UINT,
                amount1Max: MAX_UINT,
                recipient: owner.address,
                deadline: MAX_UINT,
              });
              const amounts: BigNumber[] = [callstaticData[2], callstaticData[3]];
              const ticketId: BigNumber = callstaticData[1];
              //Act
              await liqManager.connect(user1).supply({
                token0: token0.address,
                token1: token1.address,
                fee: fees[poolType],
                lowestRangeIndex: lowestIndex,
                highestRangeIndex: highestIndex,
                liqToAdd: liqToAdd,
                amount0Max: amounts[0].toString(),
                amount1Max: amounts[1].toString(),
                recipient: user1.address,
                deadline: MAX_UINT,
              });

              await pool.connect(user1).burn(user1.address, ticketId.toString());
              const userBalancesAfter = [await token0.balanceOf(pool.address), await token1.balanceOf(pool.address)];
              //Assert
              expect(userBalancesAfter[0].gte(userBalancesBefore[0].sub(amounts[0].div(ACCEPTED_LOSS)))).to.be.true;
              expect(userBalancesAfter[1].gte(userBalancesBefore[1].sub(amounts[1].div(ACCEPTED_LOSS)))).to.be.true;
            });

            const NUMBER_OF_SUPPLIES_PER_USER = 5;
            it('5 supplies and then 5 burns per user(3 users)', async function () {
              //Arrange
              const ACCEPTED_LOSS = BigNumber.from(100000); //denominator of 1/denominator
              let userBalancesBefore: [BigNumber, BigNumber][] = [];
              let userBalancesAfter: [BigNumber, BigNumber][] = [];
              let amounts: [BigNumber, BigNumber][] = [];
              let ticketId: BigNumber[] = [];
              //Act
              for (let num = 0; num < NUMBER_OF_SUPPLIES_PER_USER; num++) {
                for (let use = 1; use < users.length; use++) {
                  userBalancesBefore.push([await token0.balanceOf(pool.address), await token1.balanceOf(pool.address)]);
                  const liqToAdd: BigNumber = BigNumber.from(getRandomInt(100000)).mul(E14);
                  const callstaticData = await liqManager.callStatic.supply({
                    token0: token0.address,
                    token1: token1.address,
                    fee: fees[poolType],
                    lowestRangeIndex: lowestIndex,
                    highestRangeIndex: highestIndex,
                    liqToAdd: liqToAdd,
                    amount0Max: MAX_UINT,
                    amount1Max: MAX_UINT,
                    recipient: users[use].address,
                    deadline: MAX_UINT,
                  });
                  amounts.push([callstaticData[2], callstaticData[3]]);
                  ticketId.push(callstaticData[1]);
                  await liqManager.connect(users[use]).supply({
                    token0: token0.address,
                    token1: token1.address,
                    fee: fees[poolType],
                    lowestRangeIndex: lowestIndex,
                    highestRangeIndex: highestIndex,
                    liqToAdd: liqToAdd.toString(),
                    amount0Max: callstaticData[2].toString(),
                    amount1Max: callstaticData[3].toString(),
                    recipient: users[use].address,
                    deadline: MAX_UINT,
                  });
                }
              }
              for (let num = NUMBER_OF_SUPPLIES_PER_USER - 1; num >= 0; num--) {
                for (let use = users.length - 1; use > 0; use--) {
                  await pool.connect(users[use]).burn(users[use].address, ticketId[num * (users.length - 1) + use - 1].toString());
                  userBalancesAfter.push([await token0.balanceOf(pool.address), await token1.balanceOf(pool.address)]);
                }
              }
              //Assert
              for (let num = 0; num < NUMBER_OF_SUPPLIES_PER_USER; num++) {
                for (let use = 1; use < users.length; use++) {
                  let i = num * (users.length - 1) + use - 1;
                  let j = NUMBER_OF_SUPPLIES_PER_USER * (users.length - 1) - i - 1;
                  expect(userBalancesAfter[i][0].gte(userBalancesBefore[j][0].sub(amounts[i][0].div(ACCEPTED_LOSS)))).to.be.true;
                  expect(userBalancesAfter[i][1].gte(userBalancesBefore[j][1].sub(amounts[i][1].div(ACCEPTED_LOSS)))).to.be.true;
                }
              }
            });
          });
        });
      }
    });
  }
}
