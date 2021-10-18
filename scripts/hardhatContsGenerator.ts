import fs from 'fs';
import { ContractInput } from 'hardhat-ethernal/dist/src/types';
import { contractNames } from './consts';

export const contractNamesHardhatConstsMap = Object.freeze({
  [contractNames.multicall]: 'MULTICALL',
  [contractNames.poolDeployer]: 'POOL_DEPLOYER',
  [contractNames.factory]: 'FACTORY',
  [contractNames.swapRouter]: 'SWAP_ROUTER',
  [contractNames.liquidityManager]: 'LIQUDITY_MANAGER',
  [contractNames.liquidityManagerHelper]: 'LIQUIDITY_MANAGER_HELPER',
  [contractNames.tokenA]: 'TOKENA',
  [contractNames.tokenB]: 'TOKENB',
  [contractNames.pool]: 'POOL',
});

export const generateHardhatConsts = (contractMetadatas: Record<string, ContractInput>) => {
  const content = `export const DESIRE_SWAP_HARDHAT_ADDRESSES = {
  ${Object.entries(contractNamesHardhatConstsMap).map(([contractName, hardhatConstName]) => `${hardhatConstName}: '${contractMetadatas[contractName].address}'\n`)}};`;

  try {
    fs.writeFileSync('./hardhatConsts.ts', content);
    //file written successfully
  } catch (err) {
    console.error(err);
  }
};
