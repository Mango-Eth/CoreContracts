/// @title Compounder
/// @author Built with love, by Skirk Labs ~ John Smith

/// SPDX-License-Identifier: BUSL.2
pragma solidity ^0.8.20;

import "./Acheron_Oracle.sol";
import {IAcheron_Compounder} from "./interfaces/IAcheron_Compounder.sol";

contract Acheron_Compounder is Acheron_Oracle, IAcheron_Compounder {

    using FullMath for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using TickMath for int24;

    // error SumMismatch(uint256 wethValue, uint256 xSkirkAmount, uint256 total, uint256 requiredTotal);

    constructor(
        address _xSkirkWeth,
        address _xSkirk
    ) Acheron_Oracle(
        _xSkirkWeth, _xSkirk
    ){}

    // event MangoUint256(uint256, uint256, uint160);
    // event Step(uint256);
    // event FinalAmounts(uint256, uint256, uint256 Price);
    // event SearchedAmounts(uint256, uint256);
    // event AfterSwap(uint256, uint256);

    // event StartSearch(uint256);
    // event SkirkRemaining(uint256);
    // event LiquidityAndPrice(uint256, uint128, uint160);

    ///@notice Definitive Aggregation function to provide liquidity:
    /// Requires amount to be more than 5e18;
    /// To get rid of stagnated WETH, compound will call _claim then balanceOf() and said amount must be passed here.
    /// Compound needs to call this function with say amount2Spend: 350e18(350 dollars to deposit meaning the sum is 1000.), wethAmount must always be all the weth!, xSkirk amount must only be "remaining needed amount".
    function _aggregate_(uint256 _skirkAmount, uint256 _wethAmount, uint256 amount2Spend, uint8 flag) internal returns(uint256){
        // require(amount2Spend > MIN_AMOUNT, "AC: MA");
        // CACHE:
        uint256 skirkAmount = _skirkAmount;         // Durin compound this cuold also be more 100 dai.
        uint256 wethAmount = _wethAmount;           // During compound this could be more 0.1(100 dai)
        uint256 totalAmount = amount2Spend;         // This amount is the desired L to get! so 54$ would only use said amount.
        // We get strong TWAP WETH price.
        uint256 wethPrice = _getWethPrice();
        // WETH/xSKIRK sqrtPrice:
        (uint160 sqrtP_n,,,,,,) = IUniswapV3Pool(xSKIRK_WETH_POOL).slot0();
        // Finding liquidity:
        uint128 liquidity;
        uint8 FLAG = flag;
        uint256 a0;
        uint256 a1;
        // emit StartSearch(totalAmount);
        if(sqrtP_n < LG){
            uint256 wethAmount_ = _daiToWeth(wethPrice, totalAmount - totalAmount.mulDiv(3, 100) / 100);
            uint128 _L = LiquidityMath.getLiquidityForAmounts(sqrtP_n, tl_SqrtP, tu_SqrtP, wethAmount_, 1e18);
            liquidity = _L;
        } else if(sqrtP_n >= UG){
            uint256 wethAmount_ = _daiToWeth(wethPrice, (totalAmount / 100));   // Rest in xSkirk.
            uint128 _L = LiquidityMath.getLiquidityForAmounts(sqrtP_n, tl_SqrtP, tu_SqrtP, wethAmount_, totalAmount - ((totalAmount * 3) / 100));
            liquidity = _L;
        } else {
            if(MEDIAN_POINT < _getErInBase18(sqrtP_n, 18, 18)){
                liquidity = _UMS(totalAmount, wethPrice, sqrtP_n);
            }else{
                liquidity = _LMS(totalAmount, wethPrice, sqrtP_n);
            }
        }
        // emit LiquidityAndPrice(wethPrice, liquidity, sqrtP_n);
        // Handling swaps: Always ask for specific amount0Out +100, because of the division loss.
        uint256 skirkRemaining;
        (a0, a1, skirkRemaining) = _handlingSwap(liquidity, wethPrice, wethAmount, skirkAmount, sqrtP_n, FLAG);
        
        ///@notice Since this function only checks that the amount deposited is more than the amount2Spend - 15%,
        ///higher methods must ensure the amount deposited isnt MORE than the amount2Spend.
        //          what got deposited                  amount2Spend - 15%
        require((_wethToDai(wethPrice, a0) + a1 ) >= ((totalAmount - totalAmount.mulDiv(15, 100)) - 1000), "C: LM");

        // Add requires to ensure sum is correct.
        return (skirkRemaining);
    }
    /*
    284958772113060175  Sum of 30% deposit.
    284999999999999000
    */  
    // event AmountsToLp(uint256, uint256);
    // event SkirkAmount(uint256);
    event Marker(uint256);
    function _handlingSwap(
        uint128 _liquidity,
        uint256 _wethPrice,
        uint256 _wethAmount,
        uint256 _xSkirkAmount,
        uint160 _sqrtPrice,
        uint8 _flag
    ) internal returns(uint256, uint256, uint256){
        // CACHE:
        uint128 liquidity = _liquidity;
        uint8 flag = _flag;
        uint160 sqrtPrice = _sqrtPrice;
        uint256 wethPrice = _wethPrice;
        uint256 wethAmount = _wethAmount;
        uint256 xSkirkAmount = _xSkirkAmount;
        // 
        uint256 a0;
        uint256 a1;
        uint256 wethRequired;
        uint256 skirkRequired;
        (wethRequired, skirkRequired) = LiquidityMath.getAmountsForLiquidity(sqrtPrice, tl_SqrtP, tu_SqrtP, liquidity);
        // emit AmountsToLp(wethRequired, skirkRequired);
        wethRequired = wethRequired > 0 ? (wethRequired + 1) : 0;
        skirkRequired = skirkRequired > 0 ? (skirkRequired + 1) : 0;  // Adding 1 wei to account for the liquidityMath rounding down division.

        uint256 remaining0;
        uint256 remaining1;
        // Checks if the LP position only needs WETH:
        if(skirkRequired == 0) {
            emit Marker(1);
            if(wethAmount >= wethRequired){             // If we have enough WETH to mint already, we do.
                (a0, a1) = _mint(liquidity);
                remaining0 = wethAmount - a0;
                remaining1 = xSkirkAmount;              // Unused amount
                if(_wethToDai(wethPrice, remaining0) > 1e16){
                    // Swap said amount to DAI then Wrap to xSkirk.
                    uint256 xSkirkObtained = _ensureInWeth(remaining0, wethPrice, flag);
                    remaining1 = remaining1 + xSkirkObtained;
                    return (a0, a1, remaining1);
                }  
                return(a0, a1, remaining1);             // Unused is returned, if any.
            } else {
                // If we dont have enough weth for the sole weth position, we swap the skirk we SHOULD have until we get it.
                remaining1 = _ensureOut(wethRequired - wethAmount, xSkirkAmount, wethPrice, flag);
                (a0, a1) = _mint(liquidity);
                return(a0, a1, remaining1);   
            }
        // Check if the LP position only needs xSKIRK:
        } else if(wethRequired == 0) {              // If we have enough xSkirk to mint already, we do.
            emit Marker(2);
            if(xSkirkAmount >= skirkRequired){
                (a0, a1) = _mint(liquidity);
                remaining0 = wethAmount;            // Unused amount.
                remaining1 = xSkirkAmount - a1;
                if(_wethToDai(wethPrice, remaining0) > 1e16){           // Unused weth gets swapped to xSkirk if enough present.
                    uint256 xSkirkObtained = _ensureInWeth(remaining0, wethPrice, flag);
                    remaining1 = remaining1 + xSkirkObtained;
                    return (a0, a1, remaining1);
                }
                return(a0, a1, remaining1);
            } else {                                // We dont have enough xSkirk, so we swap the default weth for it.
                uint256 xSkirkObtained = _ensureInWeth(wethAmount, wethPrice, flag);  // We swap all our weth to xSkirk.
                remaining1 = xSkirkAmount + xSkirkObtained;                     // Total of xSkirk we have now.
                if(remaining1 >= skirkRequired){
                    (a0, a1) = _mint(liquidity);
                    return (a0, a1, remaining1 - a1);                           // No more weth here.
                }
                (a0, a1) = _mint(LiquidityMath.getLiquidityForAmounts(sqrtPrice, tl_SqrtP, tu_SqrtP, 0, remaining1 - 1));
                return (a0, a1, remaining1 > a1 ? remaining1 - a1 : 0);
            }                      
        // Checking if we have enough WETH & enough xSkirk:                          
        } else if(wethAmount >= wethRequired && xSkirkAmount >= skirkRequired){
            emit Marker(3);
            // We have enough to instantly _mint then swap the remaining WETH to DAI or xSKIRK.
            (a0, a1) = _mint(liquidity);                // We mint
            remaining0 = wethAmount - a0;
            remaining1 = xSkirkAmount - a1;                 // Subtract the intial amount - what was used.
            if(_wethToDai(wethPrice, remaining0) > 1e16){   // Weth surpluss gets swapped to xSkirk.
                // Swap said amount to DAI then Wrap to xSkirk.
                emit Marker(remaining0);
                uint256 xSkirkObtained = _ensureInWeth(remaining0, wethPrice, flag);
                return (a0, a1, remaining1 + xSkirkObtained);
            }                                                
            return (a0, a1, remaining1);

        // Checking if we have enough xSkirk but not enough Weth:
        } else if(wethAmount < wethRequired && xSkirkAmount > skirkRequired){           // mint() enters here mostly:
            emit Marker(4);
            remaining1 = _ensureOut(wethRequired - wethAmount, xSkirkAmount, wethPrice, flag);     // This ensures wethRequired is obtained.
            if(remaining1 >= skirkRequired){    // If we have enough xSkirk still for the amount required we mint.
                (a0, a1) = _mint(liquidity);    
                return(a0, a1, remaining1 - a1);
            }
            // To prevent any reverts, this will re-calculate the L amount. But will only be the case on very expensive swaps.
            (a0, a1) = _mint(LiquidityMath.getLiquidityForAmounts(sqrtPrice, tl_SqrtP, tu_SqrtP, wethRequired - 1, remaining1 - 1));
            remaining0 = wethRequired > a0 ? wethRequired - a0 : 0;
            remaining1 = remaining1 > a1 ? remaining1 - a1 : 0;
            if(_wethToDai(wethPrice, remaining0) > 1e16){                       // Swaps to dai need to be accounted for the wrapping loss into xSkirk!!!
                // Swap said amount to DAI then Wrap to xSkirk.
                uint256 xSkirkObtained_Swap = _ensureInWeth(remaining0, wethPrice, flag);
                return (a0, a1, remaining1 + xSkirkObtained_Swap);
            }  
            return(a0, a1, remaining1);                                         // Might have weth in dust, but will get scooped in next compound.
        // Checking if we have enough Weth but not enough xSkirk:
        } else if(wethAmount > wethRequired && xSkirkAmount < skirkRequired){    // Can only be called by compound(). 
            emit Marker(5);
            // Since we already have a surpluss of weth, we swap everything to xSkirk:
            remaining0 = wethAmount - wethRequired;
            remaining1 = xSkirkAmount;
            if(_wethToDai(wethPrice, remaining0) > 1e16){                       // If the surpluss is more than dust, we get it in xSkirk.
                uint256 xSkirkObtained = _ensureInWeth(wethAmount - wethRequired, wethPrice, flag);
                remaining1 = remaining1 + xSkirkObtained;
            }
            if(remaining1 >= skirkRequired){
                (a0, a1) = _mint(liquidity); 
                return (a0, a1, remaining1 - a1);
            } else {
                // Since swapping out excess WETH does not guarantee that we will have enough to mint we get a new liquidity:
                (a0, a1) = _mint(LiquidityMath.getLiquidityForAmounts(sqrtPrice, tl_SqrtP, tu_SqrtP, wethRequired - 1, remaining1 - 1));
                remaining0 = wethRequired > a0 ? wethRequired - a0 : 0;
                remaining1 = remaining1 > a1 ? remaining1 - a1 : 0;
                
                if(_wethToDai(wethPrice, remaining0) > 1e16){                       
                    uint256 xSkirkObtained_Swap = _ensureInWeth(remaining0, wethPrice, flag);
                    return (a0, a1, (remaining1 + xSkirkObtained_Swap));
                }  
                return (a0, a1, remaining1); 
            }                                                                   
        }
        revert("Insufficient funds for liquidity provision"); 
    }

    function _UMS(
        uint256 amount2Spend,
        uint256 price,
        uint160 sqrtP_n
    ) internal pure returns(uint128){
        // CACHE:
        uint256 totalAmount = amount2Spend;                            // 200e18
        uint256 target = amount2Spend - amount2Spend.mulDiv(3, 100);    // 194e18
        uint256 wethPrice = price;
        // Small value:
        uint256 sumOnePercent = target / 100;
        // Starting values:
        uint256 _a0 = 1e18;         //Irrelevant since here xSKIRK is favoured.
        uint256 _a1 = target;                                           // 194e18 on first iteration.
        uint256 diff;
        // Stop the loop:
        uint8 limit;

        // Starting loop:
        while(limit != 9){
            uint128 _L = LiquidityMath.getLiquidityForAmounts(sqrtP_n, tl_SqrtP, tu_SqrtP, _a0, _a1);
            (uint256 a0, uint256 a1) = LiquidityMath.getAmountsForLiquidity(sqrtP_n, tl_SqrtP, tu_SqrtP, _L);
            uint256 value = _wethToDai(wethPrice, a0);
            uint256 sum = value + a1;

            // Checking if ratios satisfy to break:
            if(sum >= target && totalAmount > sum){
                _a0 = a0;
                _a1 = a1;
                break;
            } else if(sum > target){        // Spread exceeds budget:
                // Check by how much this L overpays:
                diff = sum - target;

                _a0 = a0;                   // Again irrelevant
                // Large diff: reduces xSkirk amount by half the difference.
                // Low diff  : reduces xSkirk by exactly said difference.
                _a1 = diff > sumOnePercent ? a1 - (diff/2) : _a1 - diff;

            } else if(sum < target){        // Spread is bellow min deposit
                // Checks by how much this L is missing target.
                diff = target - sum;
                _a0 = a0;                   // u know
                _a1 = _a1 + diff;           // Here we just add the difference regardless.
            }
            // emit LowerM(_price, a0, a1, _a0, _a1, diff, sum);
            limit++;
        }
        return(LiquidityMath.getLiquidityForAmounts(sqrtP_n, tl_SqrtP, tu_SqrtP, _a0, _a1));
    }

    function _LMS(
        uint256 amount2Spend,
        uint256 price,
        uint160 sqrtP_n
    ) internal pure returns(uint128){
        // CACHE:
        uint256 totalAmount = amount2Spend;
        uint256 target = amount2Spend - amount2Spend.mulDiv(3, 100);
        uint256 wethPrice = price;
        // Small value:
        uint256 sumFourPercent = target / 25;
        uint256 sumOnePercent = target / 100;
        // Starting values:
        uint256 _a0 = _daiToWeth(wethPrice, target);       // 200 dai worth in WETH at the current "price". 
        uint256 _a1 = totalAmount;                                      //Irrelevant since here WETH is favoured.      
        uint256 diff;
        // Stop the loop:
        uint8 limit;
        
        while(limit != 9){
            uint128 _L = LiquidityMath.getLiquidityForAmounts(sqrtP_n, tl_SqrtP, tu_SqrtP, _a0, _a1);
            (uint256 a0, uint256 a1) = LiquidityMath.getAmountsForLiquidity(sqrtP_n, tl_SqrtP, tu_SqrtP, _L);
            uint256 value = _wethToDai(wethPrice, a0);
            uint256 sum = value + a1;
            
            // Checking if ratios satisfy to break:
            if(sum >= target && totalAmount > sum){
                _a0 = a0;
                _a1 = a1;
                break;
            } else if(sum > target){        // Spread exceeds budget:
                diff = sum - target;
                _a1 = a1;                   // Irrelevant
                _a0 = diff > sumFourPercent ? _a0 - (_daiToWeth(wethPrice, diff) / 2) : _a0 - _daiToWeth(wethPrice, diff);
            } else if(sum < target){
                diff = target - sum;
                _a1 = _a1 + diff;           
                _a0 = diff > sumOnePercent ? _a0 + (_daiToWeth(wethPrice, diff) / 2) : _a0 = _a0 + _daiToWeth(wethPrice, diff);
            }
            limit++;
            }
            return (LiquidityMath.getLiquidityForAmounts(sqrtP_n, tl_SqrtP, tu_SqrtP, _a0, _a1));
    }

    ///@notice Returns DAI exchangeRate for a given wethAmount.
    function _wethToDai(uint256 _wethPrice, uint256 _wethAmount) internal pure returns (uint256 daiER) {
        daiER = _wethPrice.mulDiv(_wethAmount, 1e18);
    }

    ///@notice Returns WETH exchangeRate for a given daiAmount.
    function _daiToWeth(uint256 _wethPrice, uint256 _daiAmount) internal pure returns(uint256){
        return _daiAmount.mulDiv(1e18, _wethPrice);
    }

    //////////////////////////////////////////////////////////////////
    //                         Core methods:                        //
    //////////////////////////////////////////////////////////////////

    /// @notice Together with the callback, provides liquidity to a fix position.
    /// * Assumes the contract holds enough funds for the spread at that time.
    function _mint(uint128 liquidity) internal returns(uint256, uint256){
        
        return IUniswapV3Pool(xSKIRK_WETH_POOL).mint(
            address(this),
            TL,
            TU,
            liquidity,
            ""
        );
    }

    /// @notice Swaps for exact amount OUT.
    function _exactOut(
        SwapParams memory s
    ) private returns (uint256 amountIn) {
        bytes memory data = abi.encode(SwapCallbackData({
            tokenIn: s.tokenIn,
            tokenOut: s.tokenOut,
            fee: s.fee
        }));
        address pool = IUniswapV3Factory(UniFactory).getPool(s.tokenIn, s.tokenOut, s.fee);
        bool zeroForOne = s.tokenIn < s.tokenOut;
        (int256 amount0Delta, int256 amount1Delta) = IUniswapV3Pool(pool).swap(
            address(this),
            zeroForOne,
            -s.amount.toInt256(),
            (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1),
            data
        );
        uint256 amountOutReceived;
        (amountIn, amountOutReceived) = zeroForOne
            ? (uint256(amount0Delta), uint256(-amount1Delta))
            : (uint256(amount1Delta), uint256(-amount0Delta));
        require(amountOutReceived >= s.amount, "C: MI");
    }

    /// @notice Regular swap of specified amount IN.
    function _exactIn(
        SwapParams memory s
    ) private returns (uint256 amountOut) {
        bytes memory data = abi.encode(SwapCallbackData({
            tokenIn: s.tokenIn,
            tokenOut: s.tokenOut,
            fee: s.fee
        }));
        address pool = IUniswapV3Factory(UniFactory).getPool(s.tokenIn, s.tokenOut, s.fee);
        bool zeroForOne = s.tokenIn < s.tokenOut;
        (int256 amount0, int256 amount1) = IUniswapV3Pool(pool).swap(
            address(this),
            zeroForOne,
            s.amount.toInt256(),
            (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1),
            data
        );
        return uint256(-(zeroForOne ? amount1 : amount0));
    }

    ///@notice Gatheres the max amount of rewards earned by lp position.
    function _claim() internal returns(uint256 a0, uint256 a1){
        IUniswapV3Pool(xSKIRK_WETH_POOL).burn(TL, TU, 0);
        (a0, a1) = IUniswapV3Pool(xSKIRK_WETH_POOL).collect(
            address(this),
            TL,
            TU,
            2**128-1,
            2**128-1
        );
    }

    //////////////////////////////////////////////////////////////////
    //                         SWAP functions:                      //
    //////////////////////////////////////////////////////////////////

    ///@notice Wrapper function of _exactIn for excess WETH transfers.
    function _ensureInWeth(uint256 amountIn, uint256 price, uint8 flag) internal returns(uint256 xSkirkOut){
        uint256 valueInDAI = _wethToDai(price, amountIn);
        uint256 _daiOut = _exactIn(SwapParams({
            tokenIn: WETH,   
            tokenOut: DAI, 
            fee: flag == 1 ? 3000 : 500,      
            amount: amountIn
        }));
        require(_daiOut >= valueInDAI - valueInDAI.mulDiv(5, 100), "C: WU");
        xSkirkOut = IxSkirk(xSKIRK).exactIn(IERC20(DAI).balanceOf(address(this)));
    }

    /// @notice Wrapper function of _exactIn() for slippage protection. 
    ///@dev TokenIn is always DAI.
    ///@return xSkirkRemaining
    ///@return wethReceived
    function _ensureIn(uint256 amountIn, uint256 amountToSpend, uint256 price, uint8 flag) internal returns(uint256, uint256) {
        require(amountIn <= amountToSpend, "AC: MEV");
        uint256 amountReceived = _exactIn(SwapParams({
            tokenIn: DAI,   
            tokenOut: WETH, 
            fee: flag == 1 ? 3000 : 500,      
            amount: amountIn
        }));
        uint256 valueInDAI = _wethToDai(price, amountReceived);
        require(valueInDAI >= amountIn - amountIn.mulDiv(33, 1000), "C: FU");
        return(amountReceived, amountToSpend - amountIn);
    }

    event MengoCheck(uint256);
    /// @notice Wrapper function of _exactOut() for slippage protection. 
    ///@dev TokenIn is always DAI.
    ///@return xSkirkRemaining
    function _ensureOut(uint256 amountOut, uint256 amountToSpend,uint256 price, uint8 flag) internal returns(uint256) {
            uint256 amountUsed = _exactOut(SwapParams({
                tokenIn: DAI,
                tokenOut: WETH,
                fee: flag == 1 ? 3000 : 500,
                amount: amountOut
            }));
            uint256 valueInDAI = _wethToDai(price, amountOut);
            emit MengoCheck(price);         // 2800                 
            emit MengoCheck(valueInDAI);    // 123 dai in weth
            emit MengoCheck(amountOut);     // 0.04
            emit MengoCheck(amountUsed);    // 128 dai spent
            require(amountUsed <= valueInDAI + valueInDAI.mulDiv(33, 1000), "C: FL"); // ~3.3%
            require(amountUsed <= amountToSpend, "AC: VEM");
            return(amountToSpend - amountUsed);
    }

    //////////////////////////////////////////////////////////////////
    //                         Callbacks & modifiers:               //
    //////////////////////////////////////////////////////////////////

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata 
    ) external {
        require(msg.sender == xSKIRK_WETH_POOL, "C: NP");

        if (amount0Owed > 0) IERC20(WETH).safeTransfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(xSKIRK).safeTransfer(msg.sender, amount1Owed);
    }

    function uniswapV3SwapCallback( /// Since this contract is only meant to swap with the wbtc/dai pool, the address can be hardcoded as the msg.sender
        int256 amount0Delta,        /// Furthermore, the amounts requested to be swapped in DAI for the specific amountn of WBTC out, can be handeled here intead.
        int256 amount1Delta,        /// It would be best to .burn() only the required amount after the swap went through.
        bytes calldata _data
    ) external {
        require(amount0Delta > 0 || amount1Delta > 0, "C: DT");
        SwapCallbackData memory decoded = abi.decode(_data, (SwapCallbackData));
        require(msg.sender == IUniswapV3Factory(UniFactory).getPool(decoded.tokenIn, decoded.tokenOut, decoded.fee), "C: WM");

        if (amount0Delta > 0){                      // DAI required:    @Mango worries me!
            uint256 amount = SafeCast.toUint256(amount0Delta);
            IxSkirk(xSKIRK).burn(amount);
            IERC20(DAI).safeTransfer(msg.sender, amount);
        }
        if (amount1Delta > 0){
            IERC20(WETH).safeTransfer(msg.sender, SafeCast.toUint256(amount1Delta));
        }
    }
}
/*
    114680639999984027491
    114680639999999354684

    7482168357522
    7482168357522

    114680639999984027490
    114680639999999354684
    114680639999984027491
    114680639999984027491
    114680639999968700298
*/


/*
    1* Create SkirkSwapFactory
    2* AcheronCompounder will now be in xSKIRK/WETH
    3* Burning xSKIRK to dai for swaps, must be handeled in SwapCallback.(UniswapFactory Check ONLY)
    4* Lp deposits bellow median tick, must be handeled with exactOut in swapCallback, burning only the necesary.
    5* Minting lp via MintCallback, must check SkirkSwapFactory!
*/