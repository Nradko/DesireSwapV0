const Web3 = require("web3")
const FactoryABI = require('./abis/factory.js').abi

const INFURA_URL = 'https://rinkeby.infura.io/v3/b8d988be9f2d4bdf9f13f4d1341f1060'
const PRIVATE_KEY = '0xc127f74ddcb1d2386137c3b02b790f8314df725786a912ca0d89335bfd16eb62'
const FACTORY_ADDRESS = "0xaB5C9D0fB75D1fe053Cf863003256A2ab5497709"



async function owner() {
    try{
        const web3 = new Web3(INFURA_URL)
        const factoryContract = new web3.eth.Contract(
        FactoryABI,
        FACTORY_ADDRESS
        )
        
        const ownerAddress = await factoryContract.methods.owner().call()
        console.log('owner: %s',ownerAddress)

        const feeCollectorAddress = await factoryContract.methods.feeCollector().call()
        console.log('feeCollector: %s',feeCollectorAddress)        
    }catch(error){
        console.log('Error')
    }    
}

owner();