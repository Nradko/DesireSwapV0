// const { expect, assert } = require("chai");
// const hre = require("hardhat");
// require("../scripts/LiquidityHelper");
// const {Interface} = require('@ethersproject/abi');
// const { abi } = require('../artifacts/contracts/LiquidityManager.sol/LiquidityManager.json');
// const {BigNumber} = require('@ethersproject/bignumber');

// const PoolABI = require('./abis/PoolABI.js').abi

// const POOL_FEES = [
//   "400000000000000",
//   "500000000000000",
//   "3000000000000000",
//   "10000000000000000"
// ]

// const POOL_RANGES = [ 1, 10, 50, 200]

// const TICK_SIZE = BigNumber.from("1000049998750062496");
// const D = BigNumber.from("1000000000000000000")

// describe("RangeMultiplier", function () {
//   it("Should return the new greeting once it's changed", async function () {
//     const [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9] = await ethers.getSigners();
//     const users = [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9];
          
//     const Deployer = await ethers.getContractFactory("PoolDeployer");
//     const deployer = await Deployer.deploy();
          
//     const Factory = await ethers.getContractFactory("DesireSwapV0Factory");
//     const factory = await Factory.deploy(owner.address, deployer.address);

//     const Token = await ethers.getContractFactory("TestERC20");
//     const tokenA = await Token.deploy("TOKENA", "TA", owner.address);
//     const tokenB = await Token.deploy("TOKENB", "TB", owner.address);

//     const Pool = await ethers.getContractFactory("DesireSwapV0Pool");

//       await factory.createPool(tokenA.address, tokenB.address, POOL_FEES[0], "DesireSwap LP: TOKENA-TOKENB","DS_TA-TB_LP");
//       let poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, POOL_FEES[0]);
//       console.log('a')
//       let pool = await Pool.attach(poolAddress);
//       console.log('a')
//       let sqrtRangeMultiplier = await pool.sqrtRangeMultiplier.toString();
//       console.log('a')
//       let sqrtRangeMultiplierExpected = D;
//       console.log('a')
//       for (let step = 0; step < 1; step++){
//         console.log('a')
//         sqrtRangeMultiplierExpected = sqrtRangeMultiplierExpected.mul(TICK_SIZE).div(D);
//       }
//       sqrtRangeMultiplierExpected = sqrtRangeMultiplierExpected.toString();
//       console.log('a')
//       console.log("got: %s;   expected: %s",sqrtRangeMultiplier, sqrtRangeMultiplierExpected);
//       console.log('a')
//       expect(sqrtRangeMultiplier).to.equal(sqrtRangeMultiplierExpected);
//   });
// });
