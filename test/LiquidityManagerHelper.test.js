const { expect, assert } = require("chai");
const hre = require("hardhat");
require("../scripts/LiquidityHelper");
const {Interface} = require('@ethersproject/abi');
const {BigNumber} = require('@ethersproject/bignumber');


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
const fee = "500000000000000"
const initialized = 0
const activate = 100
const multiplier = 1.002501875*1.002501875;

describe("LiquidityManagerHelper", async function () {
	this.timeout(0);
    it("TESTing...", async function () {
		console.log("Deploying...")
            const [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9] = await ethers.getSigners();
            const users = [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9];
            console.log("owner:%s",owner.address);
            
            const Deployer = await ethers.getContractFactory("PoolDeployer");
            const deployer = await Deployer.deploy();
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

            await factory.createPool(tokenA.address, tokenB.address, fee, "DesireSwap LP: TOKENA-TOKENB","DS_TA-TB_LP");
            console.log("tu")
            const poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fee);
            console.log('Pool address: %s', poolAddress);
		    const Pool = await ethers.getContractFactory("DesireSwapV0Pool");
		    const pool = await Pool.attach(poolAddress);
        console.log("done")

		console.log("initializing pool....");
            await pool.initialize(initialized);
        console.log("done");
        
        for (let step = 1; step < 10; step++){
            let user = users[step]
            //console.log(user.address);
            await tokenA.connect(owner).transfer(user.address, tokenSupply);
            await tokenB.connect(owner).transfer(user.address, tokenSupply);

            await tokenA.connect(user).approve(liqManager.address, tokenSupply);
            await tokenB.connect(user).approve(liqManager.address, tokenSupply);
            await tokenA.connect(user).approve(router.address, tokenSupply);
            await tokenB.connect(user).approve(router.address, tokenSupply);
        }
            await tokenA.connect(owner).approve(router.address, tokenSupply);
            await tokenB.connect(owner).approve(router.address, tokenSupply);

            console.log("firstSupply")
            await liqManager.connect(A9).supply({
                "token0": tokenA.address,
                "token1": tokenB.address,
                "fee": fee,
                "lowestRangeIndex" : 0 + initialized,
                "highestRangeIndex": 0 + initialized,
                "liqToAdd": "10000000",
                "amount0Max":"100000000000000000000000",
                "amount1Max": "10000000000000000000000000",
                "recipient": A9.address,
                "deadline": "1000000000000000000000000"
            });
            consoleBalances(poolAddress, tokenA, tokenB);
            await pool.connect(owner).activate(activate);
            await pool.connect(owner).activate(-activate);

            for(let i = 0;  i < 4; i++){
                for(let step = 0; step < 2; step++){
                    let provider = users[2*i+1];
                    
                    let data= await lmHelper.token1Supply(tokenA.address, tokenB.address, fee, BigNumber.from("100000000").div(10).toString(), -2*(i+1)*(step+1) + initialized, 2*(i+1)*(step+1) + initialized);
                    let {0:liqToAdd, 1: amount1} = data;
                    console.log(liqToAdd.toString());

                    await liqManager.connect(provider).supply({
                        "token0": tokenA.address,
                        "token1": tokenB.address,
                        "fee": fee,
                        "lowestRangeIndex" : -2*(i+1)*(step+1) + initialized,
                        "highestRangeIndex": 2*(i+1)*(step+1) + initialized,
                        "liqToAdd": liqToAdd.toString(),
                        "amount0Max":tokenSupply,
                        "amount1Max": tokenSupply,
                        "recipient": provider.address,
                        "deadline": "1000000000000000000000000"
                    });
                    await consoleBalances(pool.address, tokenA, tokenB);
                }
            }

        
        
    
    });
});

