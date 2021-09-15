require("@nomiclabs/hardhat-waffle");
require('hardhat-contract-sizer');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const INFURA_URL = 'https://rinkeby.infura.io/v3/b8d988be9f2d4bdf9f13f4d1341f1060';
const PRIVATE_KEY = '0xc127f74ddcb1d2386137c3b02b790f8314df725786a912ca0d89335bfd16eb62';

module.exports = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    rinkeby: {
      url: INFURA_URL,
      accounts:  [PRIVATE_KEY]
    }
  },  
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  }
};

