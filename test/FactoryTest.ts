import chai, { expect } from 'chai'
import { Contract, Wallet } from 'ethers'
import { AddressZero } from '@ethersproject/constants'
import { Web3Provider } from '@ethersproject/providers'
import { solidity, MockProvider, createFixtureLoader, deployContract } from 'ethereum-waffle'

// import { getCreate2Address } from './shared/utilities'

import DesireSwapV0Factory from '../artifacts/contracts/Factory.sol/DesireSwapV0Factory.json'

// import UniswapV2Pair from '../build/UniswapV2Pair.json'

chai.use(solidity)

const TEST_ADDRESSES: [string, string] = [
  '0x1000000000000000000000000000000000000000',
  '0x2000000000000000000000000000000000000000'
]

interface FactoryFixture {
  factory: Contract
}

const overrides = {
  gasLimit: 9999999
}

async function factoryFixture(wallets: Wallet[], _: Web3Provider): Promise<FactoryFixture> {
  const wallet = wallets[0]
  const factory = await deployContract(wallet, DesireSwapV0Factory, [wallet.address], overrides)
  return { factory }
}

describe('UniswapV2Factory', () => {
  const provider = new MockProvider()
  const wallets = provider.getWallets()
  const loadFixture = createFixtureLoader(wallets, provider)

  let factory: Contract
  beforeEach(async () => {
    const fixture = await loadFixture(factoryFixture)
    factory = fixture.factory
  })

  it('setBody', async () => {
    await factory.setBody(wallets[1].address)
    expect(await factory.body()).to.eq(wallets[1].address)
  })

  // async function createPair(tokens: [string, string]) {
  //   const bytecode = `0x${UniswapV2Pair.evm.bytecode.object}`
  //   const create2Address = getCreate2Address(factory.address, tokens, bytecode)
  //   await expect(factory.createPair(...tokens))
  //     .to.emit(factory, 'PairCreated')
  //     .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], create2Address, 1)

  //   await expect(factory.createPair(...tokens)).to.be.reverted // UniswapV2: PAIR_EXISTS
  //   await expect(factory.createPair(...tokens.slice().reverse())).to.be.reverted // UniswapV2: PAIR_EXISTS
  //   expect(await factory.getPair(...tokens)).to.eq(create2Address)
  //   expect(await factory.getPair(...tokens.slice().reverse())).to.eq(create2Address)
  //   expect(await factory.allPairs(0)).to.eq(create2Address)
  //   expect(await factory.allPairsLength()).to.eq(1)

  //   const pair = new Contract(create2Address, JSON.stringify(UniswapV2Pair.abi), provider)
  //   expect(await pair.factory()).to.eq(factory.address)
  //   expect(await pair.token0()).to.eq(TEST_ADDRESSES[0])
  //   expect(await pair.token1()).to.eq(TEST_ADDRESSES[1])
  // }

  // it('createPair', async () => {
  //   await createPair(TEST_ADDRESSES)
  // })

  // it('createPair:reverse', async () => {
  //   await createPair(TEST_ADDRESSES.slice().reverse() as [string, string])
  // })

  // it('createPair:gas', async () => {
  //   const tx = await factory.createPair(...TEST_ADDRESSES)
  //   const receipt = await tx.wait()
  //   expect(receipt.gasUsed).to.eq(2512920)
  // })

  // it('setFeeTo', async () => {
  //   await expect(factory.connect(other).setFeeTo(other.address)).to.be.revertedWith('UniswapV2: FORBIDDEN')
  //   await factory.setFeeTo(wallet.address)
  //   expect(await factory.feeTo()).to.eq(wallet.address)
  // })

  // it('setFeeToSetter', async () => {
  //   await expect(factory.connect(other).setFeeToSetter(other.address)).to.be.revertedWith('UniswapV2: FORBIDDEN')
  //   await factory.setFeeToSetter(other.address)
  //   expect(await factory.feeToSetter()).to.eq(other.address)
  //   await expect(factory.setFeeToSetter(wallet.address)).to.be.revertedWith('UniswapV2: FORBIDDEN')
  // })
})
