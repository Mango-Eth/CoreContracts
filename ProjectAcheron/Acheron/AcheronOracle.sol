/// @title TWAP price oracle for the average WETH price in the last 30 minutes.
/// @author Built with love, by Skirk Labs ~ John Smith

/// SPDX-License-Identifier: BUSL.2
pragma solidity ^0.8.20;

import "./AcheronBase.sol";

contract AcheronOracle is AcheronBase {

	constructor(
        address _xSkirkWeth,
        address _xSkirk,
        address _dai,
        address _weth,
        address _skirkAggregator,
        address _dai_weth,
        address _uniFactory
    ) AcheronBase(
        _xSkirkWeth, _xSkirk, _dai, _weth, _skirkAggregator, _dai_weth, _uniFactory
    ){}

	// Testnet only:
	function _getWethPrice() internal view returns(uint256){
		(uint160 sqrtP,,,,,,) = IUniswapV3Pool(dai_weth).slot0();
		uint256 rate = _getErInBase18(sqrtP, 18, 18);
		return 1e36/rate;
	}

	///////////////////////////////////////////////////////////////////////////
	// 						Interanl-Pure functions:						 // 
	///////////////////////////////////////////////////////////////////////////

	function _getErInBase18(uint160 sqrtPrice, uint256 d0, uint256 d1) internal pure returns(uint256 price){
        uint8 flag = d1 < d0 ? 0 : 1;
        if(flag == 0){
            uint256 numerator1 =uint256(sqrtPrice) *uint256(sqrtPrice);  
            uint256 numerator2 = 1e18 * 10**(d0-d1); 
            price = FullMath.mulDiv(numerator1, numerator2, 1 << 192);
        } else {
            uint256 numerator1 =uint256(sqrtPrice) *uint256(sqrtPrice);  
            uint256 numerator2 = 1e18 / 10**(d1 -d0);                // Lowering 1e18 base by decimal difference.
            uint256 _price = FullMath.mulDiv(numerator1, numerator2, 1 << 192);
            price = _price;
        }
    } 

	function _gridCheck(uint256 p1, uint256 p2) internal pure returns(uint8 tr){
		uint256 up = p1 + (p1 / 10);
		uint256 dwn = p1 - (p1 / 10);
		tr = p2 > dwn && p2 < up ? 1 : 0;
	} 
}
