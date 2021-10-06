const { BigNumber } = require('@ethersproject/bignumber');
const { ethers } = require('hardhat');

const tokenSupply = '100000000000000000000000000000000';
const fee = '500000000000000';
const initialized = 0;
const activate = 100;

async function main() {
    try{
        console.log("Deploying...")
            const [account] = await ethers.getSigners();
            console.log('Deploying contracts with the account: %s', account.address);

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
            console.log("deployer: %s", deployer.address)
            
            const Factory = await ethers.getContractFactory("DesireSwapV0Factory");
            const factory = await Factory.deploy(owner.address, deployer.address);
            console.log('Factory address: %s', factory.address);
        
            const Router = await ethers.getContractFactory("SwapRouter");
            const router = await Router.deploy(factory.address, owner.address);
            console.log('Router address: %s', router.address);

            const LiqManager = await ethers.getContractFactory("LiquidityManager");
            const liqManager = await LiqManager.deploy(factory.address, owner.address);
            console.log('liq address: %s', liqManager.address);

            const THelper = await ethers.getContractFactory("LiquidityManagerHelper");
            const tHelper = await THelper.deploy(factory.address);

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
        console.log("done");

        console.log("activating ranges");
            await pool.connect(owner).activate(activate);
            await pool.connect(owner).activate(-activate);
        console.log("activated")

        console.log("approving");
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
        console.log("approved");   
        
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
        console.log("firstSupply_done")


    } catch (err) {
        console.error('Rejection handled.',err);
    }
    await tokenA.connect(owner).approve(router.address, tokenSupply);
    await tokenB.connect(owner).approve(router.address, tokenSupply);
    console.log('approved');

    console.log('firstSupply');
    await liqManager.connect(A9).supply({
      token0: tokenA.address,
      token1: tokenB.address,
      fee: fee,
      lowestRangeIndex: 0 + initialized,
      highestRangeIndex: 0 + initialized,
      liqToAdd: '10000000',
      amount0Max: '100000000000000000000000',
      amount1Max: '10000000000000000000000000',
      recipient: A9.address,
      deadline: '1000000000000000000000000',
    });
    console.log('firstSupply_done');
  } catch (err) {
    console.error('Rejection handled.', err);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
