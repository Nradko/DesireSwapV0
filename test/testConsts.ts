import { BigNumber } from 'ethers';

export const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000';
export const MAX_INT = '57896044618658097711785492504343953926634992332820282019728792003956564819967'; //Max Int
export const E6 = BigNumber.from(10).pow(6);
export const E9 = BigNumber.from(10).pow(9);
export const E14 = BigNumber.from(10).pow(14);
export const E18 = BigNumber.from(10).pow(18);
export const usersTokensAmount = BigNumber.from('1000000000').mul(E18);
export const protocolFee = BigNumber.from(200000); //1E6

export const fees = [BigNumber.from(400), BigNumber.from(500), BigNumber.from(3000)];
export const ticksInRange = ['1', '50', '200'];
export const sqrtRangeMultipliers: BigNumber[] = [BigNumber.from('1000049998750062496'), BigNumber.from('1002503002301265502'), BigNumber.from('1010049662092876444')];
export const sqrtRangeMultipliers100: BigNumber[] = [BigNumber.from('1005012269623051144'), BigNumber.from('1284009367540270688'), BigNumber.from('2718145926825191179')];

export function getRandomInt(max: number) {
  return Math.floor(Math.random() * max);
}
