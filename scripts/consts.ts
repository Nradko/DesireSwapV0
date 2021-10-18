import { BigNumber } from 'ethers';

export const contractNames = {
  multicall: 'UniswapInterfaceMulticall',
  poolDeployer: 'PoolDeployer',
  factory: 'DesireSwapV0Factory',
  swapRouter: 'SwapRouter',
  liquidityManager: 'LiquidityManager',
  liquidityManagerHelper: 'LiquidityManagerHelper',
  tokenA: 'TOKENA',
  tokenB: 'TOKENB',
  pool: 'DesireSwapV0Pool',
};

// eslint-disable-next-line @typescript-eslint/no-magic-numbers
export const FEE = BigNumber.from(500).mul(BigNumber.from(10).pow(12));
