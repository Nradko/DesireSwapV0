import { HardhatUserConfig } from 'hardhat/types/config';
import { task } from 'hardhat/config';

require('hardhat-gas-reporter');
require('@nomiclabs/hardhat-etherscan');
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
const PRIVATE_KEY = '7563313c3fdc1fbda51327c8f14420b7af84c7650c7cb38b353361d2b5185ea3';

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
      gas: 10000000,
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
