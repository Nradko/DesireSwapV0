// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract PoolHelper {

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
                }
        } else if (y != 0) {
        z = 1;
        }
    }

    function abs(int24 x) internal pure returns (int24) {
    return x >= 0 ? x : -x;
    }

    bytes4 public constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    function _safeTransfer( address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'DesireSwapV0: TRANSFER_FAILED');
    }

    // returns 10**18 * "real LiqCoef"
    function LiqCoefficient (
        uint256 x, uint256 y,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 liqCoefficient)
    {
        //price is 10**36*real_price
        uint256 DD = 10**36;
        uint256 D = 10**18;
        uint256 b = x*(DD)/sqrt1 + y**sqrt0;
        liqCoefficient = (b + sqrt(b^2 + 4*(DD-(sqrt0*DD)/sqrt1)*D*x*y))/(2*(DD-(sqrt0*DD)/sqrt1));
    }

    function _amountIn(
        bool zeroForOne,
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1,
        uint256 amountOut, uint256 L)
        internal pure
        returns(uint256 amountIn)
    {
        uint256 D = 10**18;
        if( zeroForOne) {
            amountIn = amountOut * ( reserve0*D + L*sqrt0)/(reserve1 + (L*D)/sqrt1 - amountOut*D)/D;
        }
        else{
            amountIn = amountOut * ( reserve1*D + (L*D)*D/sqrt1)/(reserve0*D + sqrt0*L - amountOut*D)/D;
        }
    }

    function _amountOut(
        bool zeroForOne,
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1,
        uint256 amountIn, uint256 L)
        internal pure
        returns(uint256 amountOut)
    {
        uint256 D = 10**18;
        if (zeroForOne){
            amountOut = amountIn * ( reserve1*D + (L*D)*D/sqrt1)/(reserve0*D + sqrt0*L + amountIn*D)/D;
        }
        else{
            amountOut = amountIn * ( reserve0*D + L/sqrt0)/(reserve1*D + (L*D)*D/sqrt1 + amountIn*D)/D;
        }
    }

    // returns amount of token0 in that would be in position if all token0 were taken out
    function _inToken0Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1,
        uint256 L)
        internal pure
        returns (uint256 inToken0Supply)
    {
        uint256 D = 10**18;
        inToken0Supply = ((sqrt1*reserve0*reserve1*D)/L + reserve1*sqrt0*sqrt1)/D**2 + reserve0;
    }

    function _inToken0Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 inToken0Supply)
    {
        uint256 D = 10**18;
        uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        inToken0Supply = ((sqrt1*reserve0*reserve1*D)/L + reserve1*sqrt0*sqrt1)/D**2 + reserve0;
    }
    
    // currentPrice *10**36
    function _currentPrice(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 currentPrice)
    {
        uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        currentPrice = (L*L/(reserve0 + L/sqrt1)**2)*reserve1;
    }
    
    function _inToken0Value(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 inToken0Value)
    {
        uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        inToken0Value = reserve0 + (L*L/(reserve0 + L/sqrt1)**2)*reserve1/10**36;
    }


    // returns amount of token1 in that would be in position if all token0 were taken out
    function _inToken1Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1)
        internal pure
        returns (uint256 inToken1Supply)
    {
        uint256 D = 10**18;
        uint256 L = LiqCoefficient(reserve0, reserve1, sqrt0, sqrt1);
        inToken1Supply = (reserve0*reserve1*D**3/sqrt1/L + reserve0*D**2*sqrt0/sqrt1)/D**2 + reserve1;
    }

    function _inToken1Supply(
        uint256 reserve0, uint256 reserve1,
        uint256 sqrt0, uint256 sqrt1,
        uint256 L)
        internal pure
        returns (uint256 inToken1Supply)
    {
        uint256 D = 10**18;
        inToken1Supply = (reserve0*reserve1*D**3/sqrt1/L + reserve0*D**2*sqrt0/sqrt1)/D**2 + reserve1;
    }
}