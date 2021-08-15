// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IDesireSwapV0Factory
{
    event NewPoolType(uint8 poolTypeNumber, uint256 positionMultiplier, uint256 fee);
    event PoolCreated(address token0, address token1, uint8 poolType, address pool);
    event OwnerChanged(address oldOwner, address newOwner);
    event CollectorChanged(address oldFeeCollector, address newFeeCollector);
	event BodyChanged(address body, address _body);

  	function owner() external view returns (address _owner);
	function feeCollector() external view returns (address _feeCollector);
	function body() external view returns (address _body);
	function addPoolType(uint256 _sqrtPositionMultiplier, uint256 _fee) external;
  	function createPool(address tokenA, address tokenB, uint8 poolType, uint256 startingSqrtBottomPrice) external;
	function setOwner(address _owner) external;
    function setFeeCollector(address _feeCollector) external;
	function setBody(address _body) external;
}