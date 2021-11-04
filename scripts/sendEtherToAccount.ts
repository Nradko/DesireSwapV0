import { getDefaultProvider, utils, Wallet } from 'ethers';

export const sendEtherToAccount = async (receiverAddress: any, amountInEther: any) => {
  const networkAddress = 'http://127.0.0.1:8545/';

  const provider = getDefaultProvider(networkAddress);
  // Sender private key:
  const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
  // Create a wallet instance
  const wallet = new Wallet(privateKey, provider);

  // Create a transaction object
  const tx = {
    to: receiverAddress.toString(),
    // Convert currency unit from ether to wei
    value: utils.parseEther(amountInEther.toString()),
  };
  console.log('sending transaction');
  console.log(tx);
  // Send a transaction
  await wallet.sendTransaction(tx).then((txObj) => {
    console.log('txHash', txObj.hash);
    // A transaction result can be checked in a etherscan with a transaction hash which can be obtained here.
  });
  console.log('sent');
};

const argvObj = process.argv.reduce((acc, val, index) => {
  if (val.substr(0, 2) !== '--') return acc;
  acc[val.substr(2)] = process.argv[index + 1];
  return acc;
}, {} as Record<string, unknown>);

(async (args: Record<string, unknown>) => {
  if (require.main !== module) return;
  const receiverAddress = args['address'] as any;
  if (!receiverAddress) throw new Error('provide receiver address with --address flag');
  const amountInEther = args['amount'] as any;
  if (!receiverAddress) throw new Error('provide amount with --amount flag');
  await sendEtherToAccount(receiverAddress, amountInEther);
  process.exit(0);
})(argvObj).catch((e) => {
  console.log('ERROR');
  console.error(e);
  process.exit(0);
});
