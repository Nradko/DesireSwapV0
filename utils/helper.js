const fs = require("fs");
const ethers = require("ethers");

let cf, provider, deployer, accounts, ADDRESS_CONTRACT;

const defaultGas = { gasLimit: 4612388, gasPrice: '1000000000' };
const address = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";

cf = JSON.parse(fs.readFileSync("./artifacts/contracts/Factory.sol/DesireSwapV0Factory.json", "utf8"));
provider = new ethers.providers.StaticJsonRpcProvider(
    'http://127.0.0.1:8545', { name: 'hardhat', chainId: 1337 }
);

const main = async() => {
    accounts = await provider.listAccounts();
    deployer = provider.getSigner(accounts[0]);

    const contractFactory = new ethers.ContractFactory(cf.abi, cf.bytecode, deployer);
    const contract = await contractFactory.deploy(accounts[0]); // arg should be an actual poolbody address 

    await contract.deployed();
    ADDRESS_CONTRACT = contract.address;
    console.log("Contract deployed to:", ADDRESS_CONTRACT);

    await contract
        .createPool(accounts[1], accounts[2], 1000, { from: address, ...defaultGas })

    await contract
        .getPoolAddress(accounts[1], accounts[2], 1000, { from: address, ...defaultGas })
        .then(res => console.log(res));
}

main();
