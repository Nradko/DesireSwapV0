const { BigNumber } = require("@ethersproject/bignumber");
const { ethers } = require("hardhat");

const OWNER = '0x9ac5DF409766F63C752F94c17915bf0E4A8F7D08';
async function main() {
    try{
        const [deployer] = await ethers.getSigners();
        console.log('Deploying contracts with the account: %s', deployer.address);

        const balance = await deployer.getBalance();
        console.log('Account balance: %s', balance.toString());
  
        const Factory = await ethers.getContractFactory('DesireSwapV0Factory');
        const factory = await Factory.deploy(OWNER);
        console.log('Factory address: %s', factory.address);
    } catch (err) {
        console.error('Rejection handled.');
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
    console.error(error);
    process.exit(1);
    });