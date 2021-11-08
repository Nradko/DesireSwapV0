import hardhat from 'hardhat';

// below line initializes ethernal and extends hardhat env - does not work with import statement
// eslint-disable-next-line @typescript-eslint/no-unused-vars, @typescript-eslint/no-var-requires
const ethernal = require('hardhat-ethernal');
import { ContractInput } from 'hardhat-ethernal/dist/src/types';
import { task } from 'hardhat/config';
import 'hardhat/types/runtime';
import { DesireSwapV0Factory, DesireSwapV0Pool, LiquidityManager, LiquidityManagerHelper, PositionViewer, SwapRouter, DSMulticall, Quoter } from '../typechain';
import { PoolDeployer } from '../typechain/PoolDeployer';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { contractNames, FeeAmount, wrapped } from './consts';
import { generateHardhatConsts } from './hardhatContsGenerator';
import { deployContract } from './utils';
import { BigNumber } from 'ethers';
import { sendEtherToAccount } from './sendEtherToAccount';

const getContractMetadata = (contractName: string, contractAddress: string): ContractInput => ({
  name: contractName,
  address: contractAddress,
});

const synchronizeContractsWithEthernal = async (contractMetadatas: Record<string, ContractInput>) => {
  task('synchronizeContractsWithEthernal', async () => {
    for (const cMetadata of Object.values(contractMetadatas)) {
      console.log(ethernal);
      await ethernal.push(cMetadata);
    }
  });
};

const debugOwnerAddress = '0x24579c9d53751d7ef4e730f208BBEEfCbB8E6d85';

async function main() {
  try {
    console.log('DEPLOY START');

    const [account] = await hardhat.ethers.getSigners();
    console.log('Deploying contracts with the account: %s', account.address);

    const [owner] = await hardhat.ethers.getSigners();
    console.log('owner:%s', owner.address);

    const multicall = await deployContract<DSMulticall>(contractNames.multicall);
    const deployer = await deployContract<PoolDeployer>(contractNames.poolDeployer);
    const factory = await deployContract<DesireSwapV0Factory>(contractNames.factory, owner.address, deployer.address);
    const router = await deployContract<SwapRouter>(contractNames.swapRouter, factory.address, wrapped.rinkeby);
    const liqManager = await deployContract<LiquidityManager>(contractNames.liquidityManager, factory.address, wrapped.rinkeby);
    const tHelper = await deployContract<LiquidityManagerHelper>(contractNames.liquidityManagerHelper, factory.address);
    const positionViewer = await deployContract<PositionViewer>(contractNames.positionViewer);
    const swapQuoter = await deployContract<Quoter>(contractNames.swapQuoter, factory.address, wrapped.rinkeby);
    await factory.changeAllowance(swapQuoter.address);
    await factory.setSwapRouter(router.address);

    const { tokens, pools } = await deployMultipleTestTokensAndPool(owner, factory, liqManager, router, debugOwnerAddress);
    await sendEtherToAccount(debugOwnerAddress, 2);

    const deployedCoreContractMetadatas = {
      [contractNames.multicall]: getContractMetadata(contractNames.multicall, multicall.address),
      [contractNames.poolDeployer]: getContractMetadata(contractNames.poolDeployer, deployer.address),
      [contractNames.factory]: getContractMetadata(contractNames.factory, factory.address),
      [contractNames.swapRouter]: getContractMetadata(contractNames.swapRouter, router.address),
      [contractNames.liquidityManager]: getContractMetadata(contractNames.liquidityManager, liqManager.address),
      [contractNames.liquidityManagerHelper]: getContractMetadata(contractNames.liquidityManagerHelper, tHelper.address),
      [contractNames.positionViewer]: getContractMetadata(contractNames.positionViewer, positionViewer.address),
      [contractNames.swapQuoter]: getContractMetadata(contractNames.swapQuoter, swapQuoter.address),
    };

    const deployedContractMetadatas = {
      ...deployedCoreContractMetadatas,
      [contractNames.tokenA]: getContractMetadata(contractNames.tokenA, tokens.A.address),
      [contractNames.tokenB]: getContractMetadata(contractNames.tokenB, tokens.B.address),
      [contractNames.tokenUSDC]: getContractMetadata(contractNames.tokenUSDC, tokens.USDC.address),
      [contractNames.tokenUSDT]: getContractMetadata(contractNames.tokenUSDT, tokens.USDT.address),
      [contractNames.poolAB]: getContractMetadata(contractNames.poolAB, pools.AB.address),
      [contractNames.poolAUSDC]: getContractMetadata(contractNames.poolAUSDC, pools.AUSDC.address),
      [contractNames.poolBUSDC]: getContractMetadata(contractNames.poolBUSDC, pools.BUSDC.address),
      [contractNames.poolUSDCT]: getContractMetadata(contractNames.poolUSDCT, pools.USDCT.address),
    };
    generateHardhatConsts(deployedContractMetadatas);
    await synchronizeContractsWithEthernal(deployedContractMetadatas);
  } catch (err) {
    console.error('Rejection handled.', err);
  }
}

const deployMultipleTestTokensAndPool = async (owner: SignerWithAddress, factory: DesireSwapV0Factory, liqManager: LiquidityManager, swapRouter: SwapRouter, supplyingUser: string) => {
  // eslint-disable-next-line @typescript-eslint/no-magic-numbers
  const tokenSupply = BigNumber.from(10).pow(32).toString();
  const Token = await hardhat.ethers.getContractFactory('TestERC20');
  const tokenA = await Token.deploy(contractNames.tokenA, 'TA', owner.address);
  const tokenB = await Token.deploy(contractNames.tokenB, 'TB', owner.address);
  const tokenUSDC = await Token.deploy('Coinbase USD', 'USDC', owner.address);
  const tokenUSDT = await Token.deploy('Tether USD', 'USDT', owner.address);
  console.log('TA address: %s', tokenA.address);
  console.log('TB address: %s', tokenB.address);
  console.log('USDC address: %s', tokenUSDC.address);
  console.log('USDT address: %s', tokenUSDT.address);

  await factory.createPool(tokenA.address, tokenB.address, FeeAmount.MEDIUM.toString(), 'DesireSwap LP: TOKENA-TOKENB', 'DSLP:TA-TB');
  await factory.createPool(tokenA.address, tokenUSDC.address, FeeAmount.MEDIUM.toString(), 'DesireSwap LP: TOKENA-USDC', 'DSLP:TA-USDC');
  await factory.createPool(tokenUSDC.address, tokenB.address, FeeAmount.MEDIUM.toString(), 'DesireSwap LP: USDC-TOKENB', 'DSLP:USDC-TB');
  await factory.createPool(tokenUSDC.address, tokenUSDT.address, FeeAmount.LOW.toString(), 'DesireSwap LP: USDC-USDT', 'DSLP:USDC-USDT');
  const poolAddress = [
    await factory.poolAddress(tokenA.address, tokenB.address, FeeAmount.MEDIUM.toString()),
    await factory.poolAddress(tokenA.address, tokenUSDC.address, FeeAmount.MEDIUM.toString()),
    await factory.poolAddress(tokenUSDC.address, tokenB.address, FeeAmount.MEDIUM.toString()),
    await factory.poolAddress(tokenUSDC.address, tokenUSDT.address, FeeAmount.LOW.toString()),
  ];
  console.log('TA-TB address: %s', poolAddress[0]);
  console.log('TA-USDC address: %s', poolAddress[1]);
  console.log('USDC-TB address: %s', poolAddress[2]);
  console.log('USDC-USDT address: %s', poolAddress[3]);

  const PoolFactory = await hardhat.ethers.getContractFactory(contractNames.pool);
  const poolList = [
    PoolFactory.attach(poolAddress[0]) as DesireSwapV0Pool,
    PoolFactory.attach(poolAddress[1]) as DesireSwapV0Pool,
    PoolFactory.attach(poolAddress[2]) as DesireSwapV0Pool,
    PoolFactory.attach(poolAddress[3]) as DesireSwapV0Pool,
  ];
  const startingInUseRanges = [0, 100, 100, 0];
  console.log('initializing and activating poolList...');
  for (let step = 0; step < poolList.length; step++) {
    console.log('initialize');
    await poolList[step].initialize(startingInUseRanges[step]);
    await poolList[step].connect(owner).activate(startingInUseRanges[step] + 100);
    await poolList[step].connect(owner).activate(startingInUseRanges[step] - 100);
  }
  console.log('done!');
  console.log('approving');
  await tokenA.connect(owner).approve(liqManager.address, tokenSupply);
  await tokenB.connect(owner).approve(liqManager.address, tokenSupply);
  await tokenUSDC.connect(owner).approve(liqManager.address, tokenSupply);
  await tokenUSDT.connect(owner).approve(liqManager.address, tokenSupply);
  /* eslint-disable @typescript-eslint/no-magic-numbers */
  await tokenA.connect(owner).transfer(supplyingUser, BigNumber.from(10).pow(30));
  await tokenB.connect(owner).transfer(supplyingUser, BigNumber.from(10).pow(30));
  await tokenUSDC.connect(owner).transfer(supplyingUser, BigNumber.from(10).pow(30));
  await tokenUSDT.connect(owner).transfer(supplyingUser, BigNumber.from(10).pow(30));
  /* eslint-enable @typescript-eslint/no-magic-numbers */
  console.log('approved');

  await liqManager.connect(owner).supply({
    token0: tokenA.address,
    token1: tokenB.address,
    fee: FeeAmount.MEDIUM.toString(),
    lowestRangeIndex: startingInUseRanges[0],
    highestRangeIndex: startingInUseRanges[0],
    liqToAdd: '10000000000',
    amount0Max: '100000000000000000000000',
    amount1Max: '10000000000000000000000000',
    recipient: owner.address,
    deadline: '1000000000000000000000000',
  });

  await liqManager.connect(owner).supply({
    token0: tokenA.address,
    token1: tokenUSDC.address,
    fee: FeeAmount.MEDIUM.toString(),
    lowestRangeIndex: startingInUseRanges[1],
    highestRangeIndex: startingInUseRanges[1],
    liqToAdd: '10000000000',
    amount0Max: '100000000000000000000000',
    amount1Max: '10000000000000000000000000',
    recipient: owner.address,
    deadline: '1000000000000000000000000',
  });

  await liqManager.connect(owner).supply({
    token0: tokenUSDC.address,
    token1: tokenB.address,
    fee: FeeAmount.MEDIUM.toString(),
    lowestRangeIndex: startingInUseRanges[2],
    highestRangeIndex: startingInUseRanges[2],
    liqToAdd: '10000000000',
    amount0Max: '100000000000000000000000',
    amount1Max: '10000000000000000000000000',
    recipient: owner.address,
    deadline: '1000000000000000000000000',
  });
  await liqManager.connect(owner).supply({
    token0: tokenUSDC.address,
    token1: tokenUSDT.address,
    fee: FeeAmount.LOW.toString(),
    lowestRangeIndex: startingInUseRanges[3],
    highestRangeIndex: startingInUseRanges[3],
    liqToAdd: '10000000000',
    amount0Max: '100000000000000000000000',
    amount1Max: '10000000000000000000000000',
    recipient: owner.address,
    deadline: '1000000000000000000000000',
  });

  const tokens = { A: tokenA, B: tokenB, USDC: tokenUSDC, USDT: tokenUSDT };
  const pools = { AB: poolList[0], AUSDC: poolList[1], BUSDC: poolList[2], USDCT: poolList[3] };
  return { tokens, pools };
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
