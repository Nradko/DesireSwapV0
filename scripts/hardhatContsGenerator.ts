import fs from 'fs';
import { ContractInput } from 'hardhat-ethernal/dist/src/types';

export const generateHardhatConsts = (contractMetadatas: Record<string, ContractInput>) => {
  const content = `export const DESIRE_SWAP_HARDHAT_ADDRESSES = {
  ${Object.values(contractMetadatas)
    .map((contract, i, arr) => `${contract.name}: '${contract.address}',\n${i !== arr.length - 1 ? '  ' : ''}`)
    .join('')}};`;

  try {
    fs.writeFileSync('./hardhatConsts.ts', content);
    //file written successfully
  } catch (err) {
    console.error(err);
  }
};
