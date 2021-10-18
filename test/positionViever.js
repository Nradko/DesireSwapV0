const { expect, assert } = require("chai");
const hre = require("hardhat");
require("../scripts/LiquidityHelper");
const {Interface} = require('@ethersproject/abi');
const { abi } = require('../artifacts/contracts/LiquidityManager.sol/LiquidityManager.json');
const {BigNumber} = require('@ethersproject/bignumber');

const PoolABI = require('./abis/PoolABI.js').abi

async function consoleBalances(owner, token0, token1){
	const balanceA = await token0.balanceOf(owner);
	const balanceB = await token1.balanceOf(owner);
	console.log("%s balances -> tokenA: %s -> tokenB: %s",owner,balanceA.toString(), balanceB.toString());
}

async function consoleReserves(pool){
	const reserves = await pool.getTotalReserves();
    let {0: totReserve0, 1: totReserve1} = reserves;
    console.log("totalReserves -> tokenA: %s -> tokenB: %s", totReserve0.toString(), totReserve1.toString());
}

async function totalReserve0(pool){
    const reserves = await pool.getTotalReserves();
    let {0: totReserve0, 1: totReserve1} = reserves;
    return totReserve0.toString();
}

async function totalReserve1(pool){
    const reserves = await pool.getTotalReserves();
    let {0: totReserve0, 1: totReserve1} = reserves;
    return totReserve1.toString();
}

async function consoleSum(owner, token0, token1){
	const balanceA = await token0.balanceOf(owner);
	const balanceB = await token1.balanceOf(owner);
	console.log("%s balances -> tokenA: %s -> tokenB: %s -> SUM: ",owner,balanceA.toString(), balanceB.toString(),balanceA.add(balanceB).toString());
}

async function getTotalReserves(pool){
    const reserves = pool.getTotalReserves();
    console.log("totalResereves are: %s and %s", reserves[1].toString(), reserves[2].toString());
}

const tokenSupply = "100000000000000000000000000000000";
const fee = "400000000000000"
const initialized = -4000
const multiplier = 1.002501875*1.002501875;

describe("Multiple_swaps", function () {
	this.timeout(0);
    it("TESTing...", async function () {
		console.log("Deploying...")
            const [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9] = await ethers.getSigners();
            console.log("owner:%s",owner.address);
            
            const Deployer = await ethers.getContractFactory("PoolDeployer");
            const deployer = await Deployer.deploy();
            console.log("deployed deployer");
            console.log("deployer: %s", deployer.address)
            
            const Factory = await ethers.getContractFactory("DesireSwapV0Factory");
            const factory = await Factory.deploy(owner.address, deployer.address);
            console.log('Factory address: %s', factory.address);
            expect( await factory.owner(), 'get facoty owner').to.eq(owner.address);

            const Router = await ethers.getContractFactory("SwapRouter");
            const router = await Router.deploy(factory.address, owner.address);
            console.log('Router address: %s', router.address);

            await factory.connect(owner).setSwapRouter(router.address);
            expect(await factory.swapRouter() == router.address);

            const LiqManager = await ethers.getContractFactory("LiquidityManager");
            const liqManager = await LiqManager.deploy(factory.address, owner.address);
            console.log('liq address: %s', liqManager.address);

            const LMHelper = await ethers.getContractFactory("LiquidityManagerHelper");
            const lmHelper = await LMHelper.deploy(factory.address);

            const Token = await ethers.getContractFactory("TestERC20");
            const tokenA = await Token.deploy("TOKENA", "TA", owner.address);
            const tokenB = await Token.deploy("TOKENB", "TB", owner.address);
            console.log('TA address: %s', tokenA.address);
            console.log('TB address: %s', tokenB.address);

            const Viewer = await ethers.getContractFactory('PositionViewer');
            const viewer = await Viewer.deploy();

            await factory.createPool(tokenA.address, tokenB.address, fee, "DesireSwap LP: TOKENA-TOKENB","DS_TA-TB_LP");
            const poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fee);
            console.log('Pool address: %s', poolAddress);
		    const Pool = await ethers.getContractFactory("DesireSwapV0Pool");
		    const pool = await Pool.attach(poolAddress);
        console.log("done")


		console.log("initializing pool....");
            await pool.initialize(initialized);
        console.log("done");


            await tokenA.connect(owner).approve(liqManager.address, tokenSupply);
            await tokenB.connect(owner).approve(liqManager.address, tokenSupply);

            const token0 = tokenA.address < tokenB.address ? tokenA : tokenB;
            const token1 = tokenA.address > tokenB.address ? tokenA : tokenB;

            
        for( let step = 0; step < 10; step++){
            await liqManager.connect(owner).supply({
                "token0": tokenA.address,
                "token1": tokenB.address,
                "fee": fee,
                "lowestRangeIndex" : -20*step + initialized,
                "highestRangeIndex": 20*step + initialized,
                "liqToAdd": "10000000000000000000000000000",
                "amount0Max":"100000000000000000000000000000000000",
                "amount1Max": "10000000000000000000000000000000000",
                "recipient": owner.address,
                "deadline": "1000000000000000000000000"
            });
        await consoleBalances(pool.address, tokenA, tokenB);    
        }
        const DATA = await viewer.getPositionDataList(poolAddress, owner.address);
        console.log(DATA);
    });
});

