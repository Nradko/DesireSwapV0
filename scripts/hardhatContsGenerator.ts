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
  [contractNames.positionViewer]: 'POSITION_VIEWER',
});

export const generateHardhatConsts = (contractMetadatas: Record<string, ContractInput>) => {
  const content = `import { BigNumber } from "ethers";

export const DESIRE_SWAP_HARDHAT_ADDRESSES = {
  ${Object.entries(contractNamesHardhatConstsMap)
    .map(([contractName, hardhatConstName], i, arr) => `${hardhatConstName}: '${contractMetadatas[contractName].address}',\n${i !== arr.length - 1 ? '  ' : ''}`)
    .join('')}};
// eslint-disable-next-line @typescript-eslint/no-magic-numbers
export const FEE = BigNumber.from(500).mul(BigNumber.from(10).pow(12));`;

  try {
    fs.writeFileSync('./hardhatConsts.ts', content);
    //file written successfully
  } catch (err) {
    console.error(err);
  }
};
