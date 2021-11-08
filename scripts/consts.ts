export const contractNames = {
  multicall: 'DSMulticall',
  poolDeployer: 'PoolDeployer',
  factory: 'DesireSwapV0Factory',
  swapRouter: 'SwapRouter',
  liquidityManager: 'LiquidityManager',
  liquidityManagerHelper: 'LiquidityManagerHelper',
  tokenA: 'TOKENA',
  tokenB: 'TOKENB',
  token: 'TestERC20',
  pool: 'DesireSwapV0Pool',
  positionViewer: 'PositionViewer',
  swapQuoter: 'Quoter',
  tokenUSDC: 'CoinbaseUSD',
  tokenUSDT: 'TetherUSD',
  poolAB: 'poolAB',
  poolAUSDC: 'poolAUSDC',
  poolBUSDC: 'poolBUSDC',
  poolUSDCT: 'poolUSDCT',
};

export const testTokenNames = ['TokenA', 'TokenB', 'Coinbase USD', 'Tether USD'];
export const testTokenShortNames = ['TA', 'TB', 'USDC', 'USDT'];

export enum FeeAmount {
  LOW = 400,
  MEDIUM = 500,
  HIGH = 3000,
}

export const wrapped = {
  hardhat: '0x0000000000000000000000000000000000000000',
  rinkeby: '0xc778417E063141139Fce010982780140Aa0cD5Ab',
};
