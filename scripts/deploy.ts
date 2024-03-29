import hardhat from 'hardhat';

// below line initializes ethernal and extends hardhat env - does not work with import statement
// eslint-disable-next-line @typescript-eslint/no-unused-vars, @typescript-eslint/no-var-requires
const ethernal = require('hardhat-ethernal');
import { ContractInput } from 'hardhat-ethernal/dist/src/types';
import { task } from 'hardhat/config';
import 'hardhat/types/runtime';
import { DesireSwapV0Factory, DesireSwapV0Pool, LiquidityManager, LiquidityManagerHelper, PositionViewer, SwapRouter, UniswapInterfaceMulticall, Quoter } from '../typechain';
import { PoolDeployer } from '../typechain/PoolDeployer';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { contractNames, FeeAmount } from './consts';
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

const debugOwnerAddress = '0x3e19756F2A1e0aC7d7327B2bCAc0dcd5966be2bE';

async function main() {
  try {
    console.log('DEPLOY START');

    const [account] = await hardhat.ethers.getSigners();
    console.log('Deploying contracts with the account: %s', account.address);

    const [owner] = await hardhat.ethers.getSigners();
    console.log('owner:%s', owner.address);

    const multicall = await deployContract<UniswapInterfaceMulticall>(contractNames.multicall);
    const deployer = await deployContract<PoolDeployer>(contractNames.poolDeployer);
    const factory = await deployContract<DesireSwapV0Factory>(contractNames.factory, owner.address, deployer.address);
    const router = await deployContract<SwapRouter>(contractNames.swapRouter, factory.address, owner.address);
    const liqManager = await deployContract<LiquidityManager>(contractNames.liquidityManager, factory.address, owner.address);
    const tHelper = await deployContract<LiquidityManagerHelper>(contractNames.liquidityManagerHelper, factory.address);
    const positionViewer = await deployContract<PositionViewer>(contractNames.positionViewer);
    const swapQuoter = await deployContract<Quoter>(contractNames.swapQuoter, factory.address, debugOwnerAddress);
    await factory.changeAllowance(swapQuoter.address);
    await factory.setSwapRouter(router.address);

    const { pool, tokenA, tokenB } = await deployTestTokensAndPool(owner, factory, liqManager, router, debugOwnerAddress);
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
      [contractNames.tokenA]: getContractMetadata(contractNames.tokenA, tokenA.address),
      [contractNames.tokenB]: getContractMetadata(contractNames.tokenB, tokenB.address),
      [contractNames.pool]: getContractMetadata(contractNames.pool, pool.address),
    };
    generateHardhatConsts(deployedContractMetadatas);
    await synchronizeContractsWithEthernal(deployedContractMetadatas);
  } catch (err) {
    console.error('Rejection handled.', err);
  }
}

const deployTestTokensAndPool = async (owner: SignerWithAddress, factory: DesireSwapV0Factory, liqManager: LiquidityManager, swapRouter: SwapRouter, supplyingUser: string) => {
  // eslint-disable-next-line @typescript-eslint/no-magic-numbers
  const tokenSupply = BigNumber.from(10).pow(32).toString();

  const Token = await hardhat.ethers.getContractFactory('TestERC20');
  const tokenA = await Token.deploy(contractNames.tokenA, 'TA', owner.address);
  const tokenB = await Token.deploy(contractNames.tokenB, 'TB', owner.address);
  console.log('TA address: %s', tokenA.address);
  console.log('TB address: %s', tokenB.address);

  await factory.createPool(tokenA.address, tokenB.address, FeeAmount.MEDIUM.toString(), 'DesireSwap LP: TOKENA-TOKENB', 'DS_TA-TB_LP');
  const poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, FeeAmount.MEDIUM.toString());
  console.log('Pool address: %s', poolAddress);
  const PoolFactory = await hardhat.ethers.getContractFactory(contractNames.pool);
  const pool = PoolFactory.attach(poolAddress) as DesireSwapV0Pool;
  const startingInUseRange = 0;
  await pool.initialize(startingInUseRange);
  console.log('activating ranges');
  const upperRangeToActivate = 100;
  const lowerRangeToActivate = 100;
  await pool.connect(owner).activate(upperRangeToActivate);
  await pool.connect(owner).activate(-lowerRangeToActivate);
  console.log('activated');

  await tokenA.connect(owner).approve(liqManager.address, tokenSupply);
  await tokenB.connect(owner).approve(liqManager.address, tokenSupply);
  // eslint-disable-next-line @typescript-eslint/no-magic-numbers
  await tokenA.connect(owner).transfer(supplyingUser, BigNumber.from(10).pow(30));
  // eslint-disable-next-line @typescript-eslint/no-magic-numbers
  await tokenB.connect(owner).transfer(supplyingUser, BigNumber.from(10).pow(30));

  await tokenA.connect(owner).approve(swapRouter.address, tokenSupply);
  await tokenB.connect(owner).approve(swapRouter.address, tokenSupply);
  console.log('approved');

  await liqManager.connect(owner).supply({
    token0: tokenA.address,
    token1: tokenB.address,
    fee: FeeAmount.MEDIUM.toString(),
    lowestRangeIndex: startingInUseRange,
    highestRangeIndex: startingInUseRange,
    liqToAdd: '10000000',
    amount0Max: '100000000000000000000000',
    amount1Max: '10000000000000000000000000',
    recipient: owner.address,
    deadline: '1000000000000000000000000',
  });
  const poolInUseInfo = await pool.inUseInfo();
  console.log(poolInUseInfo);
  return { tokenA, tokenB, pool };
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
