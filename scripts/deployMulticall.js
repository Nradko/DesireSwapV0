/* eslint-disable no-undef */
const { ethers } = require('hardhat');

async function main() {
  try {
    const Multicall = await ethers.getContractFactory('UniswapInterfaceMulticall');
    const multicall = await Multicall.deploy();
    console.log('XD');
    console.log(`multicall address: ${multicall.address}`);
  } catch (err) {
    console.error('Rejection handled.', err);
  }
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
