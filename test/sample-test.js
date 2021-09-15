const { expect, assert } = require("chai");
const hre = require("hardhat");
require("../scripts/LiquidityHelper");
const {Interface} = require('@ethersproject/abi');
const { abi } = require('../artifacts/contracts/LiquidityManager.sol/LiquidityManager.json');
const {BigNumber} = require('@ethersproject/bignumber');

const PoolABI = require('./abis/PoolABI.js').abi

describe("Deploy", function () {
	it("TESTing...", async function () {
		const [owner, A1, A2, A3] = await ethers.getSigners();
		console.log("A2:%s",A2.address);
		
		const Factory = await ethers.getContractFactory("DesireSwapV0Factory");
		const factory = await Factory.deploy(owner.address);
		console.log('Factory address: %s', factory.address);

		expect( await factory.owner(), 'get facoty owner').to.eq(owner.address);
		

		const Router = await ethers.getContractFactory("SwapRouter");
		const router = await Router.deploy(factory.address, A3.address);
		console.log('Router address: %s', router.address);

		const LiqManager = await ethers.getContractFactory("LiquidityManager");
		const liqManager = await LiqManager.deploy(factory.address, A3.address);
		console.log('liq address: %s', liqManager.address);

		const Token = await ethers.getContractFactory("TestERC20");
		const tokenA = await Token.deploy("TOKENA", "TB", A1.address, A2.address);
		console.log('TA address: %s', tokenA.address);
		const tokenB = await Token.deploy("TOKENB", "TA", A1.address, A2.address);
		console.log('TB address: %s', tokenB.address);
		const fee = "3000000000000000"
		await factory.createPool(tokenA.address, tokenB.address, fee);
		const poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fee);
		console.log('Pool address: %s', poolAddress);
		
		// expect(await factory.poolAddress(tokenA.address, tokenB.address, fee), 'getPool in order').to.eq(poolAddress)
		// expect(await factory.poolAddress(tokenB.address, tokenA.address, fee), 'getPool in reverse').to.eq(poolAddress)
		// await expect(factory.createPool(tokenA.address, tokenB.address, fee)).to.be.reverted
		// await expect(factory.createPool(tokenB.address, tokenA.address, fee)).to.be.reverted
		
		const Pool = await ethers.getContractFactory("DesireSwapV0Pool");
		const pool = await Pool.attach(poolAddress);

		// expect(await pool.token0(), 'checking token0 in pool').to.be.oneOf([tokenA.address, tokenB.address]);
		// expect(await pool.token1(), 'checking token1 in pool').to.be.oneOf([tokenA.address, tokenB.address]);
		// expect(await pool.feePercentage(), 'get fee').to.eq(fee);
		// expect(await pool.sqrtRangeMultiplier(), 'get sqrtRangeMultiplier').to.eq("1002501875000000000");

		await pool.initialize("0");
		rangeInfo = await pool.getRangeInfo("0");
		const {0: reserve0, 1: reserve1, 2: sB, 3: sT} = rangeInfo;
		// console.log(reserve0.toString());
		// console.log(reserve1.toString());
		// console.log(sB.toString());
		// console.log(sT.toString());

		const inUse = await pool.inUseRange();
		console.log(inUse);

		await tokenA.connect(A1).approve(liqManager.address, "10000000000000000000")
		await tokenB.connect(A1).approve(liqManager.address, "10000000000000000000")

		await liqManager.connect(A1).supply({
			"token0": tokenA.address,
			"token1": tokenB.address,
			"fee": fee,
			"lowestRangeIndex" : "-3",
			"highestRangeIndex": "3",
			"liqToAdd": "100000000000000000",
			"amount0Max":"10000000000000000000000000000",
			"amount1Max": "10000000000000000000000000000",
			"recipient": A1.address,
			"deadline": "1000000000000000000000000"
		});
		const tR = await pool.getLastBalances();
		console.log("tR0:%s", tR);
		const balance0 = await pool.balance0();
		const balance1 = await pool.balance1();
		console.log("balance0 %s", balance0)
		console.log("balance1 %s", balance1)

		await tokenA.connect(A2).approve(router.address, "10000000000000000000")
		await tokenB.connect(A2).approve(router.address, "10000000000000000000")
		await router.connect(A2).exactInputSingle({
			"tokenIn" : tokenA.address,
			"tokenOut": tokenB.address,
			"fee": fee,
			"recipient": A2.address,
			"deadline": "1000000000000000000000000",
			"amountIn": "1746568742000",
			"amountOutMinimum": "746568742",
			"sqrtPriceLimitX96": "0"
		})
		const A2balance0 = await tokenA.balanceOf(A2.address);
		const A2balance1 = await tokenB.balanceOf(A2.address);
		console.log(A2balance0.toString())
		console.log(A2balance1.toString())


	});
});
