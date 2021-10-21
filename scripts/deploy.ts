import hardhat from 'hardhat';

// below line initializes ethernal and extends hardhat env - does not work with import statement
// eslint-disable-next-line @typescript-eslint/no-unused-vars, @typescript-eslint/no-var-requires
const ethernal = require('hardhat-ethernal');
import { ContractInput } from 'hardhat-ethernal/dist/src/types';
import { task } from 'hardhat/config';
import 'hardhat/types/runtime';
import { DesireSwapV0Factory, DesireSwapV0Pool, LiquidityManager, LiquidityManagerHelper, SwapRouter, UniswapInterfaceMulticall } from '../typechain';
import { PoolDeployer } from '../typechain/PoolDeployer';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { contractNames, FEE } from './consts';
import { generateHardhatConsts } from './hardhatContsGenerator';
import { deployContract } from './utils';

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
    const { pool, tokenA, tokenB } = await deployTestTokensAndPool(owner, factory);

    const deployedCoreContractMetadatas = {
      [contractNames.multicall]: getContractMetadata(contractNames.multicall, multicall.address),
      [contractNames.poolDeployer]: getContractMetadata(contractNames.poolDeployer, deployer.address),
      [contractNames.factory]: getContractMetadata(contractNames.factory, factory.address),
      [contractNames.swapRouter]: getContractMetadata(contractNames.swapRouter, router.address),
      [contractNames.liquidityManager]: getContractMetadata(contractNames.liquidityManager, liqManager.address),
      [contractNames.liquidityManagerHelper]: getContractMetadata(contractNames.liquidityManagerHelper, tHelper.address),
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

const deployTestTokensAndPool = async (owner: SignerWithAddress, factory: DesireSwapV0Factory) => {
  const Token = await hardhat.ethers.getContractFactory('TestERC20');
  const tokenA = await Token.deploy(contractNames.tokenA, 'TA', owner.address);
  const tokenB = await Token.deploy(contractNames.tokenB, 'TB', owner.address);
  console.log('TA address: %s', tokenA.address);
  console.log('TB address: %s', tokenB.address);

  await factory.createPool(tokenA.address, tokenB.address, FEE.toString(), 'DesireSwap LP: TOKENA-TOKENB', 'DS_TA-TB_LP');
  const poolAddress = await factory.poolAddress(tokenA.address, tokenB.address, FEE.toString());
  console.log('Pool address: %s', poolAddress);
  const PoolFactory = await hardhat.ethers.getContractFactory(contractNames.pool);
  const pool = PoolFactory.attach(poolAddress) as DesireSwapV0Pool;
  await pool.initialize(0);
  console.log('activating ranges');
  const upperRangeToActivate = 100;
  const lowerRangeToActivate = 100;
  await pool.connect(owner).activate(upperRangeToActivate);
  await pool.connect(owner).activate(-lowerRangeToActivate);
  console.log('activated');
  return { tokenA, tokenB, pool };
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
