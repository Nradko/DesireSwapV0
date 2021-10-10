const { BigNumber } = require("@ethersproject/bignumber");
const { ethers } = require("hardhat");
const { collapseTextChangeRangesAcrossMultipleVersions } = require("typescript");

const tokenSupply = "100000000000000000000000000000000";
const fee = "500000000000000"
const initialized = 0
const activate = 100

async function main() {
    try{
        const [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9] = await ethers.getSigners();
        const users = [owner, A1, A2, A3, A4, A5, A6, A7, A8, A9];
        console.log("Deploying...")
            console.log('Deploying contracts with the owner account: %s', owner.address);
            
            const Multicall = await ethers.getContractFactory('UniswapInterfaceMulticall');
            const multicall = await Multicall.deploy();
            console.log("UniswapInterfaceMulticall deployed")

            const Deployer = await ethers.getContractFactory("PoolDeployer");
            const deployer = await Deployer.deploy();
            console.log("PoolDeployer deployed")
            
            const Factory = await ethers.getContractFactory("DesireSwapV0Factory");
            const factory = await Factory.deploy(owner.address, deployer.address);
            console.log("DesireSwapV0Factory deployed")
        
            const Router = await ethers.getContractFactory("SwapRouter");
            const router = await Router.deploy(factory.address, owner.address);
            console.log("SwapRouter deployed")

            const LiqManager = await ethers.getContractFactory("LiquidityManager");
            const liqManager = await LiqManager.deploy(factory.address, owner.address);
            console.log("LiquidityManager deployed")

            const THelper = await ethers.getContractFactory("LiquidityManagerHelper");
            const tHelper = await THelper.deploy(factory.address);
            console.log("LiquidityManagerHelper deployed")

            const Token = await ethers.getContractFactory("TestERC20");
            const tokenA = await Token.deploy("TOKENA", "TA", owner.address);
            console.log("TestERC20_TOKEN_A deployed")
            const tokenB = await Token.deploy("TOKENB", "TB", owner.address);
            console.log("TestERC20_TOKEN_B deployed")

            await factory.createPool(tokenA.address, tokenB.address, fee, "DesireSwap LP: TOKENA-TOKENB","DS_TA-TB_LP");
            const poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, fee);
            console.log("TOKENA_TOKENB POOL created")

		    const Pool = await ethers.getContractFactory("DesireSwapV0Pool");
		    const pool = await Pool.attach(poolAddress);

        console.log("+++ ALL CONTRACTS DEPLOYED +++")

        console.log("+++ initializing pool +++");
            await pool.initialize(initialized);
        console.log("done");

        console.log("activating ranges");
            await pool.connect(owner).activate(activate);
            await pool.connect(owner).activate(-activate);
        console.log("activated")

        console.log("approving");
            for (let step = 1; step <= 1; step++){
                let user = users[step]
                await tokenA.connect(owner).transfer(user.address, tokenSupply);
                await tokenB.connect(owner).transfer(user.address, tokenSupply);

                await tokenA.connect(user).approve(liqManager.address, tokenSupply);
                await tokenB.connect(user).approve(liqManager.address, tokenSupply);
                await tokenA.connect(user).approve(router.address, tokenSupply);
                await tokenB.connect(user).approve(router.address, tokenSupply);
            }
            await tokenA.connect(owner).approve(router.address, tokenSupply);
            await tokenB.connect(owner).approve(router.address, tokenSupply);
        console.log("approved");   
        
        console.log("firstSupply")
        await liqManager.connect(A1).supply({
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
        console.log("firstSupply_done")

        console.log("+++ ADDRESSES +++")
        console.log("Owner address:     %s", owner.address);
        console.log("Multicall address: %s", multicall.address);
        console.log("Factory address:   %s", factory.address);
        console.log("TOKEN A address:   %s", tokenA.address)
        console.log("TOKEN B address:   %s", tokenB.address)
        console.log("Pool address       %s:", pool.address)


    } catch (err) {
        console.error('Rejection handled.',err);
    }


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
    console.error(error);
    process.exit(1);
    });