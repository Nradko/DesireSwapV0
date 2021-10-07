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
const multiplier = 1.002501875*1.002501875;

describe("Multiple_swaps", function () {
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

            const LMHelper = await ethers.getContractFactory("LiquidityManagerHelper");
            const lmHelper = await LMHelper.deploy(factory.address);

            const Token = await ethers.getContractFactory("TestERC20");
            const tokenA = await Token.deploy("TOKENA", "TA", owner.address);
            const tokenB = await Token.deploy("TOKENB", "TB", owner.address);
            let token0 = tokenA.address < tokenB.address ? tokenA : tokenB;
            let token1 = tokenA.address > tokenB.address ? tokenA : tokenB;
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

        for(let i = 0; i < 2; i++){
            let provider = users[2*i+1];
            let swapper = users[2*i+2];
            
            for( let step = 0; step < 2; step++){
                console.log("cycle %s:%s", i, step)
                await liqManager.connect(provider).supply({
                    "token0": tokenA.address,
                    "token1": tokenB.address,
                    "fee": fee,
                    "lowestRangeIndex" : -2*(i+1)*(step+1) + initialized,
                    "highestRangeIndex": 2*(i+1)*(step+1) + initialized,
                    "liqToAdd": "10000000000000000000000000000",
                    "amount0Max":"100000000000000000000000000000000000",
                    "amount1Max": "10000000000000000000000000000000000",
                    "recipient": provider.address,
                    "deadline": "1000000000000000000000000"
                });
                expect(await pool.getAddressTickets(provider.address, 1 + step) == BigNumber.from(step+1));
                await consoleBalances(pool.address, tokenA, tokenB);

                    let totalRes0 = (await totalReserve0(pool))
                    await router.connect(swapper).exactOutputSingle({
                        "tokenIn" : token1.address,
                        "tokenOut": token0.address,
                        "fee": fee,
                        "recipient": swapper.address,
                        "deadline": "1000000000000000000000000",
                        "amountOut": totalRes0,
                        "amountInMaximum": "100000000000000000000000000000",
                        "sqrtPriceLimitX96": "0"
                    })
                    let totalRes1 = (await totalReserve1(pool))
                    console.log(totalRes1);
                    await router.connect(swapper).exactOutputSingle({
                        "tokenIn" : token0.address,
                        "tokenOut": token1.address,
                        "fee": fee,
                        "recipient": swapper.address,
                        "deadline": "1000000000000000000000000",
                        "amountOut": totalRes1,
                        "amountInMaximum": "1000000000000000000000000000001",
                        "sqrtPriceLimitX96": "0"
                    })
                    await router.connect(swapper).exactOutputSingle({
                        "tokenIn" : token1.address,
                        "tokenOut": token0.address,
                        "fee": fee,
                        "recipient": swapper.address,
                        "deadline": "1000000000000000000000000",
                        "amountOut": totalRes0,
                        "amountInMaximum": "1000000000000000000000000000001",
                        "sqrtPriceLimitX96": "0"
                    })

                console.log("cycle %s _end", step)
                await consoleBalances(provider.address, tokenA, tokenB);
                await consoleBalances(swapper.address, tokenA, tokenB);
                await consoleBalances(pool.address, tokenA, tokenB);
            }
        }
        await consoleReserves(pool);

        let reserve;
        for(let step  =0; step < 2; step++){
            console.log("swap_cycle: %s", step);
            reserve = (await totalReserve1(pool)).toString();
            await router.connect(owner).exactOutputSingle({
                "tokenIn" : token0.address,
                "tokenOut": token1.address,
                "fee": fee,
                "recipient": owner.address,
                "deadline": "1000000000000000000000000",
                "amountOut": reserve,
                "amountInMaximum": "10000000000000000000000000000000000000",
                "sqrtPriceLimitX96": "0"
            })
            await consoleReserves(pool);

            reserve = (await totalReserve0(pool)).toString();
            await router.connect(owner).exactOutputSingle({
                "tokenIn" : token1.address,
                "tokenOut": token0.address,
                "fee": fee,
                "recipient": owner.address,
                "deadline": "1000000000000000000000000",
                "amountOut": reserve,
                "amountInMaximum": "1000000000000000000000000000000000000001",
                "sqrtPriceLimitX96": "0"
            })
            await consoleReserves(pool);

            reserve = (await totalReserve1(pool)).toString();
            await router.connect(owner).exactOutputSingle({
                "tokenIn" : token0.address,
                "tokenOut": token1.address,
                "fee": fee,
                "recipient": owner.address,
                "deadline": "1000000000000000000000000",
                "amountOut": BigNumber.from(reserve).div(2).toString(),
                "amountInMaximum": "100000000000000000000000000000000001",
                "sqrtPriceLimitX96": "0"
            })
            await consoleReserves(pool);
        }


        for(let i = 0; i < 2; i++){
            let provider = users[2*i+1];
            for( let step = 0; step < 2; step++){
                console.log("remove %s:%s", i, step)
                let ticketId = await pool.getAddressTickets(provider.address, 1 + step);
                if(ticketId != 0){
                    await pool.connect(provider).burn( provider.address, ticketId);
                }
            }
        }



        await consoleBalances(pool.address, tokenA, tokenB);
        let a = totalReserve0(pool);
        let b = totalReserve1(pool);
        console.log(a.toString());
        console.log(b.toString());
        
        for( let step = -17  + initialized; step < 18  + initialized; step++){

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

        for (let step = 1; step < 9; step++){
            let user = users[step];
            await consoleSum(user.address, tokenA, tokenB);
        }

        
        
    
    });
});

