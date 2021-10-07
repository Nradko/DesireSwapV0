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
const initialized = 4000
const activate = 1000
const multiplier = 1.002501875*1.002501875;

describe("SwapRouterHelper", function () {
	this.timeout(0);
    it("TESTing...", async function () {
		console.log("Deploying...")
            const [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9] = await ethers.getSigners();
            const users = [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9];
            console.log("owner:%s",owner.address);
            
            const TickMath = await ethers.getContractFactory("TickMath");
            const tickMath = await TickMath.deploy();
            
            const Deployer = await ethers.getContractFactory("PoolDeployer",{
                libraries:{
                    TickMath: tickMath.address
                }
            });
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

            const SRHelper = await ethers.getContractFactory("SwapRouterHelper");
            const srHelper = await SRHelper.deploy(factory.address);

            const LMHelper = await ethers.getContractFactory("LiquidityManagerHelper");
            const lmHelper = await LMHelper.deploy(factory.address);

            const Token = await ethers.getContractFactory("TestERC20");
            const tokenA = await Token.deploy("TOKENA", "TA", owner.address);
            const tokenB = await Token.deploy("TOKENB", "TB", owner.address);
            console.log('TA address: %s', tokenA.address);
            console.log('TB address: %s', tokenB.address);

            await factory.createPool(tokenA.address, tokenB.address, fee, "DesireSwap LP: TOKENA-TOKENB","DS_TA-TB_LP");
            const poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fee);
            console.log('Pool address: %s', poolAddress);
		    const Pool = await ethers.getContractFactory("DesireSwapV0Pool",{
                libraries:{
                    TickMath: tickMath.address
                }
            });
		    const pool = await Pool.attach(poolAddress);
        console.log("done")


		console.log("initializing pool....");
            await pool.initialize(initialized);
            rangeInfo = await pool.getRangeInfo(initialized);
            const {0: reserve0, 1: reserve1, 2: sB, 3: sT} = rangeInfo;
        console.log("done");

        console.log("activating ranges...");
        for(let step = 1; step <=10; step++){
            await pool.connect(owner).activate(initialized + step * 100);
            await pool.connect(owner).activate(initialized - step * 100);
        }
        console.log("activated");

        console.log("approving spending...")
            for (let step = 1; step < 9; step++){
                let user = users[step]
                console.log(user.address);
                await tokenA.connect(owner).transfer(user.address, tokenSupply);
                await tokenB.connect(owner).transfer(user.address, tokenSupply);

                await tokenA.connect(user).approve(liqManager.address, tokenSupply);
                await tokenB.connect(user).approve(liqManager.address, tokenSupply);
                await tokenA.connect(user).approve(router.address, tokenSupply);
                await tokenB.connect(user).approve(router.address, tokenSupply);
            }
            await tokenA.connect(owner).approve(liqManager.address, tokenSupply);
            await tokenB.connect(owner).approve(liqManager.address, tokenSupply);
            await tokenA.connect(owner).approve(router.address, tokenSupply);
            await tokenB.connect(owner).approve(router.address, tokenSupply);
        console.log("approved");

        console.log("firstSupply")
        await liqManager.connect(owner).supply({
            "token0": tokenA.address,
            "token1": tokenB.address,
            "fee": fee,
            "lowestRangeIndex" : 0 + initialized,
            "highestRangeIndex": 0 + initialized,
            "liqToAdd": "10000000",
            "amount0Max":"100000000000000000000000",
            "amount1Max": "10000000000000000000000000",
            "recipient": owner.address,
            "deadline": "1000000000000000000000000"
        });
        console.log("firstSupplied");
        let data= await lmHelper.token0Supply(tokenA.address, tokenB.address, fee, BigNumber.from("1000000000000000000000").toString(), -100 + initialized, 100 + initialized);
        let {0:liqToAdd, 1: amount1toAdd} = data;
        console.log(liqToAdd.toString());

        await liqManager.connect(owner).supply({
            "token0": tokenA.address,
            "token1": tokenB.address,
            "fee": fee,
            "lowestRangeIndex" : -100 + initialized,
            "highestRangeIndex": 100 + initialized,
            "liqToAdd": liqToAdd.toString(),
            "amount0Max":tokenSupply,
            "amount1Max": tokenSupply,
            "recipient": owner.address,
            "deadline": "1000000000000000000000000"
        });
        await consoleReserves(pool);

        data = await srHelper.swapQuoter(tokenA.address, tokenB.address, fee, "true", "900000000000000000000", "0");

        let {0:amount0, 1:amount1} = data;
        console.log("amount0: %s   amount1:%s", amount0.toString(), amount1.toString());
        await consoleBalances(A1.address, tokenA, tokenB)
        await router.connect(A1).exactInputSingle({
            "tokenIn" : tokenA.address,
            "tokenOut": tokenB.address,
            "fee": fee,
            "recipient": A1.address,
            "deadline": "1000000000000000000000000",
            "amountIn": "100000000000000000000",
            "amountOutMinimum": "1000",
            "sqrtPriceLimitX96": "0"
        })
        await consoleBalances(A1.address, tokenA, tokenB)
    });
});