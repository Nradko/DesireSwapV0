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
  token: 'TestERC20',
  pool: 'DesireSwapV0Pool',
  positionViewer: 'PositionViewer',
};

// eslint-disable-next-line @typescript-eslint/no-magic-numbers
export const FEE = BigNumber.from(500).mul(BigNumber.from(10).pow(12));
