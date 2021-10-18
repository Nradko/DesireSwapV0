import { HardhatUserConfig } from 'hardhat/types/config';
import { task } from 'hardhat/config';

import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import 'hardhat-contract-sizer';

import 'hardhat-gas-reporter';
import '@nomiclabs/hardhat-etherscan';

task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const INFURA_URL = 'https://rinkeby.infura.io/v3/b8d988be9f2d4bdf9f13f4d1341f1060';
const PRIVATE_KEY = '0xc127f74ddcb1d2386137c3b02b790f8314df725786a912ca0d89335bfd16eb62';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.4',
    settings: {
      optimizer: {
        enabled: true,
        runs: 20,
      },
    },
  },
  networks: {
    rinkeby: {
      url: INFURA_URL,
      accounts: [PRIVATE_KEY],
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  // etherscan: {
  //   apiKey: ETHERSCAN_API_KEY,
  // },
  // gasReporter: {
  //   currency: "USD",
  //   gasPrice: 100,
  //   // enabled: process.env.REPORT_GAS ? true : false,
  // },
};

export default config;
