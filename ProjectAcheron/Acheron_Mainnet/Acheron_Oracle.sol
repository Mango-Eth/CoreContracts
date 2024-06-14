/// @title TWAP price oracle for the average WETH price in the last 30 minutes.
/// @author Built with love, by Skirk Labs ~ John Smith

/// SPDX-License-Identifier: BUSL.2
pragma solidity ^0.8.20;

import "./Acheron_Base.sol";

contract Acheron_Oracle is Acheron_Base {

	constructor(
		address _xSkirkWeth,
		address _xSkirk
	) Acheron_Base(_xSkirkWeth, _xSkirk){}

	///@notice Etherscan quality of life.
	// event GivenPrices(uint256 usdc_weth, uint256 weth_usdt, uint256 cl);

	///@notice Price fetching function to get trustworthy WETH price.
	///@dev Will make sure that both TWAPs are in range with eachother. 
	/// Any failures to update by chainlink, will be accounted for, since 0 values are handeled.
	function _getWethPrice() internal view returns(uint256){
		uint256 uniTwap1 = _usdcWeth();
		uint256 uniTwap2 = _wethUsdt();
		uint256 chainLFeed = _getWethPrice_chainLink();
		if(chainLFeed > 0){
			require(_gridCheck(uniTwap1, uniTwap2) == 1 && _gridCheck(uniTwap1, chainLFeed) == 1, "O: c_vlt");
			return uniTwap1;
		}
		require(_gridCheck(uniTwap1, uniTwap2) == 1, "O: vlt");
		// emit GivenPrices(uniTwap1, uniTwap2, chainLFeed);
		return uniTwap1;
	}

	///////////////////////////////////////////////////////////////////////////
	// 						External calls:		   							 // 
	///////////////////////////////////////////////////////////////////////////

	///@notice Gets the current WETH price if the Chainlink v3 aggregator was updated in the last 1 hour.
	function _getWethPrice_chainLink() internal view returns(uint256 price){
		int256 p;
		if(CANCEL == 0){
			return 0;
		}

		try dataFeed.latestRoundData()
		returns (uint80, int256 _p, uint256, uint256 _delay, uint80)
		{
			uint256 delayFromHeartbeat = block.timestamp - _delay;
			if(delayFromHeartbeat <= 60 minutes){
				p = _p;
			} else {
				p = 0;
			}
		}
		catch (bytes memory){}

		if(p < 0){
			price = 0;
		} else {
			price = uint256(p) * 10**10;
		}
	}
	
	///@notice Geometric mean TWAP from uni v3 pool. WETH/USDT
	function _wethUsdt() internal view returns(uint256){
        uint256 maxTime = 1800;
        uint32[] memory time = new uint32[](2);
        time[0] = uint32(maxTime);
        time[1] = 0;
        (int56[] memory ticks,) = IUniswapV3Pool(USDT_WETH).observe(time);
        int24 spotTick = int24((ticks[1] - ticks[0]) / int56(uint56(maxTime)));
        uint256 er = _getErInBase18(TickMath.getSqrtRatioAtTick(spotTick), 18, 6);
		return er;
    }

	///@notice Geometric mean TWAP from uni v3 pool. USDC/WETH
    function _usdcWeth() internal view returns(uint256){
        uint256 maxTime = 1800;
        uint32[] memory time = new uint32[](2);
        time[0] = uint32(maxTime);
        time[1] = 0;
        (int56[] memory ticks,) = IUniswapV3Pool(USDC_WETH).observe(time);
        int24 spotTick = int24((ticks[1] - ticks[0]) / int56(uint56(maxTime)));
        uint256 er = _getErInBase18(TickMath.getSqrtRatioAtTick(spotTick), 6, 18);
		return 1e36 / er;
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
