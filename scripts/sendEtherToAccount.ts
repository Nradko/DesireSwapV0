const ethers = require('ethers');

const argvObj = process.argv.reduce((acc, val, index) => {
  if (val.substr(0, 2) !== '--') return acc;
  acc[val.substr(2)] = process.argv[index + 1];
  return acc;
}, {});

(async (args) => {
  const receiverAddress = args['address'];
  if (!receiverAddress) throw new Error('provide receiver address with --address flag');
  const amountInEther = args['amount'];
  if (!receiverAddress) throw new Error('provide amount with --amount flag');

  const networkAddress = 'http://127.0.0.1:8545/';

  const provider = ethers.getDefaultProvider(networkAddress);
  // Sender private key:
  // correspondence address 0xb985d345c4bb8121cE2d18583b2a28e98D56d04b
  const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
  // Create a wallet instance
  const wallet = new ethers.Wallet(privateKey, provider);

  // Create a transaction object
  const tx = {
    to: receiverAddress.toString(),
    // Convert currency unit from ether to wei
    value: ethers.utils.parseEther(amountInEther.toString()),
  };
  console.log('sending transaction');
  console.log(tx);
  // Send a transaction
  await wallet.sendTransaction(tx).then((txObj) => {
    console.log('txHash', txObj.hash);
    // => 0x9c172314a693b94853b49dc057cf1cb8e529f29ce0272f451eea8f5741aa9b58
    // A transaction result can be checked in a etherscan with a transaction hash which can be obtained here.
  });
  console.log('sent');
  process.exit(0);
})(argvObj).catch((e) => {
  console.log('ERROR');
  console.error(e);
  process.exit(0);
});
