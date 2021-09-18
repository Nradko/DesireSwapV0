const {BigNumber} = require('@ethersproject/bignumber');

async function consoleBalances(owner, token0, token1){
	const balanceA = await token0.balanceOf(owner);
	const balanceB = await token1.balanceOf(owner);
	console.log("%s balances -> tokenA: %s -> tokenB: %s",owner,balanceA.toString(), balanceB.toString());
}