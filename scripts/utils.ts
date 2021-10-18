import { Contract } from 'ethers';
import hardhat from 'hardhat';

export const deployContract = async <T extends Contract>(contractName: string, ...deployArgs: string[]) => {
  const ContractFactory = await hardhat.ethers.getContractFactory(contractName);
  const contractInstance = (await ContractFactory.deploy(...deployArgs)) as T;
  console.log(`${contractName} address: ${contractInstance.address}`);
  return contractInstance;
};
