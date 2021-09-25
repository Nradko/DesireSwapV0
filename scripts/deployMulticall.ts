const hardhat = require('hardhat');

async function main() {
  try {
    const Multicall = await hardhat.ethers.getContractFactory('Multicall');
    const multicall = await Multicall.deploy();
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
