const Web3 = require("web3")
const FactoryABI = require('./abis/factory.js').abi

const INFURA_URL = 'https://rinkeby.infura.io/v3/b8d988be9f2d4bdf9f13f4d1341f1060'
const PUBLIC_KEY = '0x9ac5DF409766F63C752F94c17915bf0E4A8F7D08'
const PRIVATE_KEY = '0xc127f74ddcb1d2386137c3b02b790f8314df725786a912ca0d89335bfd16eb62'
const FACTORY_ADDRESS = "0xaB5C9D0fB75D1fe053Cf863003256A2ab5497709"

const web3 = new Web3(INFURA_URL);

module.exports.getBlockNumber = async function() {
    const latestBlockNumber = await web3.eth.getBlockNumber()
    console.log(latestBlockNumber)
    return latestBlockNumber
}

module.exports.owner = async function() {
    try{
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )
        const ownerAddress = await factoryContract.methods.owner().call()
        console.log('owner: %s',ownerAddress)
    }catch(error){
        console.log('Error')
    }  
}

module.exports.feeCollector = async function() {
    try{
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )
        const feeCollectorAddress = await factoryContract.methods.feeCollector().call()
        console.log('feeCollector: %s',feeCollectorAddress)
    }catch(error){
        console.log('Error')
    }  
}

module.exports.feeToSqrtRangeMultiplier = async function( fee) {
    try{
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )
        const feeToSqrtRangeMultiplierValue = await factoryContract.methods.feeToSqrtRangeMultiplier(fee).call()
        console.log('feeToSqrtRangeMultiplier: %s',feeToSqrtRangeMultiplierValue)
    }catch(error){
        console.log('Error')
    }  
}

module.exports.poolAddress = async function(tokenA, tokenB, _fee) {
    try{
        fee= BigInt(_fee)
        console.log('tu')
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )
        console.log('tu')
        const _poolAddress = await factoryContract.methods.poolAddress(tokenA, tokenB, fee).call()
        console.log('tu')
        console.log('poolAddress: %s', _poolAddress)
    }catch(error){
        console.log('Error: %s', error)
    }  
}

module.exports.poolList = async function(number) {
    try{
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )
        const poolList = await factoryContract.methods.poolList(number).call()
        console.log('poolList[%s]: %s', number, poolList)
    }catch(error){
        console.log('Error')
    }  
}

module.exports.poolCount = async function() {
    try{
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )
        const poolCount = await factoryContract.methods.poolCount().call()
        console.log('poolCount: %s',  poolCount)
    }catch(error){
        console.log('Error')
    }  
}

module.exports.addPoolType = async function(_fee, _sqrtRangeMultiplier) {
    try{
        fee = BigInt(_fee)
        sqrtRangeMultiplier = BigInt(_sqrtRangeMultiplier) 
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )

        const massage = factoryContract.methods.addPoolType(fee, sqrtRangeMultiplier).encodeABI();

        const createTransaction = await web3.eth.accounts.signTransaction(
            {
                from: PUBLIC_KEY,
                to: FACTORY_ADDRESS,
                data: massage,
                gas: '100000',
            },
            PRIVATE_KEY
        )

        const transaction = await web3.eth.sendSignedTransaction(
            createTransaction.rawTransaction
        )

        console.log('Tx succes, txHash is: %s', transaction.transactionHash)
    }catch(error){
        console.log('Error: %s', error)
    }  
}

module.exports.createPool = async function(tokenA, tokenB, fee) {
    try{
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )
        const massage = factoryContract.methods.createPool(
            tokenA,
            tokenB,
            fee).encodeABI();
        const createTransaction = await web3.eth.accounts.signTransaction(
            {
                from: PUBLIC_KEY,
                to: FACTORY_ADDRESS,
                data: massage,
                gas: '10000000',
            },
            PRIVATE_KEY
        )
        const transaction = await web3.eth.sendSignedTransaction(
            createTransaction.rawTransaction
        )
        console.log('Tx succes, txHash is: %s', transaction.transactionHash)
    }catch(error){
        console.log('Error: %s', error)
    }  
}

module.exports.setOwner = async function(owner) {
    try{
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )
        const massage = factoryContract.methods.setOwner(owner).encodeABI();
        const createTransaction = await web3.eth.accounts.signTransaction(
            {
                from: PUBLIC_KEY,
                to: FACTORY_ADDRESS,
                data: massage,
                gas: '10000000',
            },
            PRIVATE_KEY
        )
        const transaction = await web3.eth.sendSignedTransaction(
            createTransaction.rawTransaction
        )
        console.log('Tx succes, txHash is: %s', transaction.transactionHash)
    }catch(error){
        console.log('Error: %s', error)
    }  
}

module.exports.setFeeCollector = async function(feeCollector) {
    try{
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )
        const massage = factoryContract.methods.setFeeCollector(feeCollector).encodeABI();
        const createTransaction = await web3.eth.accounts.signTransaction(
            {
                from: PUBLIC_KEY,
                to: FACTORY_ADDRESS,
                data: massage,
                gas: '10000000',
            },
            PRIVATE_KEY
        )
        const transaction = await web3.eth.sendSignedTransaction(
            createTransaction.rawTransaction
        )
        console.log('Tx succes, txHash is: %s', transaction.transactionHash)
    }catch(error){
        console.log('Error: %s', error)
    }  
}