const { expect, assert } = require("chai");
const hre = require("hardhat");
require("../scripts/LiquidityHelper");
const {Interface} = require('@ethersproject/abi');
const { abi } = require('../artifacts/contracts/LiquidityManager.sol/LiquidityManager.json');
const {BigNumber} = require('@ethersproject/bignumber');

const PoolABI = require('../test/abis/PoolABI.js').abi

async function consoleBalances(owner, token0, token1){
	const balanceA = await token0.balanceOf(owner);
	const balanceB = await token1.balanceOf(owner);
	console.log("%s balances -> tokenA: %s -> tokenB: %s",owner,balanceA.toString(), balanceB.toString());
}

async function getTotalReserves(pool){
    const reserves = pool.getTotalReserves();
    console.log("totalResereves are: %s and %s", reserves[1].toString(), reserves[2].toString());
}

const tokenSupply = "100000000000000000000000000000";
const fee = "3000000000000000"
const multiplier = 1.002501875*1.002501875;

describe("Many_Swaps", function () {
	it("TESTing...", async function () {
		console.log("Deploying...")
            const [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9] = await ethers.getSigners();
            const users = [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9];
            console.log("owner:%s",owner.address);
            console.log("A1:%s",A1.address);
            console.log("A2:%s",A2.address);
            
            const Factory = await ethers.getContractFactory("DesireSwapV0Factory");
            const factory = await Factory.deploy(owner.address);
            console.log('Factory address: %s', factory.address);
            expect( await factory.owner(), 'get facoty owner').to.eq(owner.address);

            const Router = await ethers.getContractFactory("SwapRouter");
            const router = await Router.deploy(factory.address, owner.address);
            console.log('Router address: %s', router.address);

            const LiqManager = await ethers.getContractFactory("LiquidityManager");
            const liqManager = await LiqManager.deploy(factory.address, owner.address);
            console.log('liq address: %s', liqManager.address);

            const Token = await ethers.getContractFactory("TestERC20");
            const tokenA = await Token.deploy("TOKENA", "TA", owner.address);
            const tokenB = await Token.deploy("TOKENB", "TB", owner.address);
            console.log('TA address: %s', tokenA.address);
            console.log('TB address: %s', tokenB.address);

            await factory.createPool(tokenA.address, tokenB.address, fee);
            const poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fee);
            console.log('Pool address: %s', poolAddress);
		    const Pool = await ethers.getContractFactory("DesireSwapV0Pool");
		    const pool = await Pool.attach(poolAddress);
        console.log("done")

		console.log("initializing pool....");
            await pool.initialize("0");
            rangeInfo = await pool.getRangeInfo("0");
            const {0: reserve0, 1: reserve1, 2: sB, 3: sT} = rangeInfo;
        console.log("done");

		const inUse = await pool.inUseRange();
		console.log(inUse);
        
        for (let step = 1; step < 10; step++){
            let user = users[step]
            await tokenA.connect(owner).transfer(user.address, tokenSupply);
            await tokenB.connect(owner).transfer(user.address, tokenSupply);

            await tokenA.connect(user).approve(liqManager.address, tokenSupply);
            await tokenB.connect(user).approve(liqManager.address, tokenSupply);
            await tokenA.connect(user).approve(router.address, tokenSupply);
            await tokenB.connect(user).approve(router.address, tokenSupply);
        }

        for(let i = 0; i < 5; i++){
            let provider = users[2*i+1];
            let swapper = users[2*i+2];
            
            for( let step = 0; step < 7; step++){
                console.log("cycle %s:%s", i, step)
                await liqManager.connect(provider).supply({
                    "token0": tokenA.address,
                    "token1": tokenB.address,
                    "fee": fee,
                    "lowestRangeIndex" : -step,
                    "highestRangeIndex": step,
                    "liqToAdd": "10000000000000000000000000000",
                    "amount0Max":"10000000000000000000000000000",
                    "amount1Max": "10000000000000000000000000000",
                    "recipient": provider.address,
                    "deadline": "1000000000000000000000000"
                });
                await consoleBalances(pool.address, tokenA, tokenB);

                await consoleBalances(pool.address, tokenA, tokenB);
                await router.connect(swapper).exactOutputSingle({
                    "tokenIn" : tokenA.address,
                    "tokenOut": tokenB.address,
                    "fee": fee,
                    "recipient": swapper.address,
                    "deadline": "1000000000000000000000000",
                    "amountOut": BigNumber.from("10000000000000000000000000").mul((step+1)*(step+2)/2).toString(),
                    "amountInMinimum": "100000000001",
                    "sqrtPriceLimitX96": "0"
                })
                console.log("cycle %s _end", step)

                await router.connect(swapper).exactOutputSingle({
                    "tokenIn" : tokenB.address,
                    "tokenOut": tokenA.address,
                    "fee": fee,
                    "recipient": swapper.address,
                    "deadline": "1000000000000000000000000",
                    "amountOut": BigNumber.from("20000000000000000000000000").mul((step+1)*(step+2)/2).toString(),
                    "amountInMinimum": "2000000000000",
                    "sqrtPriceLimitX96": "0"
                })

                await consoleBalances(pool.address, tokenA, tokenB);
                await router.connect(swapper).exactOutputSingle({
                    "tokenIn" : tokenA.address,
                    "tokenOut": tokenB.address,
                    "fee": fee,
                    "recipient": swapper.address,
                    "deadline": "1000000000000000000000000",
                    "amountOut": BigNumber.from("10000000000000000000000000").mul((step+1)*(step+2)/2).toString(),
                    "amountInMinimum": "100000000001",
                    "sqrtPriceLimitX96": "0"
                })
                console.log("cycle %s _end", step)
                await consoleBalances(provider.address, tokenA, tokenB);
                await consoleBalances(swapper.address, tokenA, tokenB);
                await consoleBalances(pool.address, tokenA, tokenB);
            }
        }

        for( let step = 0; step < 7; step++){
            console.log("remove %s", step)
            await liqManager.connect(A1).redeem({
                "positionId" : step+1,
                "recipient" : A1.address,
                "deadline" : "1000000000000000",
            })
            await consoleBalances(A1.address, tokenA, tokenB);
            await consoleBalances(pool.address, tokenA, tokenB);
        }
        await consoleBalances(A1.address, tokenA, tokenB);
        await consoleBalances(A2.address, tokenA, tokenB);
        await consoleBalances(pool.address, tokenA, tokenB);
        let a = await pool.totalReserve0();
        let b = await pool.totalReserve1();
        console.log(a.toString());
        console.log(b.toString());
        
        for( let step = -7; step < 8; step++){

            rangeInfo = await pool.getFullRangeInfo(step);
		    const {0: reserve0, 1: reserve1, 2: sB, 3: sT, 4: SC} = rangeInfo;
            // console.log(reserve0.toString())
            // console.log(reserve1.toString())
            // console.log(sB.toString())
            // console.log(sT.toString())
            // console.log("aa")
            // console.log(SC.toString())
            // console.log("aa")
            console.log("Range[%s] info: %s  %s  %s  %s  %s", step, reserve0.toString(), reserve1.toString(), sB.toString(), sT.toString(), SC.toString());
        }
        
    
    });
});

