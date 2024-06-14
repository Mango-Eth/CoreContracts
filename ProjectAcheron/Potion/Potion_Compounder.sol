/// @title Compounder
/// @author Built with love, by Skirk Labs ~ John Smith

/// SPDX-License-Identifier: BUSL.2
pragma solidity ^0.8.20;

import "./Potion_Base.sol";

contract Potion_Compounder is Potion_Base {

    using FullMath for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using TickMath for int24;

    event Comp(uint256 a0, uint256 a1, uint256 r);
    event AddxSkirk(uint256 a0, uint256 a1, uint256 r);

    ///@notice Compounding function to re-invest currently held DAI & USDC in desired amount.
    function _comp(uint256 daiAmount, uint256 usdcAmount, uint256 amount2Deposit) internal returns(uint256 f0, uint256 f1, uint256 remaining){
        require(amount2Deposit > 10e18, "PC: LA");
        (uint160 sqrtP,,,,,,) = IUniswapV3Pool(DAI_USDC_POOL).slot0();
        require(sqrtP <= tu_SqrtP && sqrtP >= tl_SqrtP, "MG: IR");
        uint128 liquidity = _getLiquidity(amount2Deposit);
        (uint256 a0, uint256 a1) = LiquidityMath.getAmountsForLiquidity(sqrtP, tl_SqrtP, tu_SqrtP, liquidity);
        require(a0 + _usdcToBase(a1) >= amount2Deposit - amount2Deposit.mulDiv(5, 100), "PC: LL");
        a0 = a0 > 0 ? (a0 + 1) : 0;
        a1 = a1 > 0 ? (a1 + 1) : 0;

        if(daiAmount >= a0 && usdcAmount >= a1){    // We have enough to mint directly, so we do.
            (f0, f1) = _mint(liquidity, 0);
            remaining = _skirkUP();
            emit Comp(f0, f1, remaining);
        } else {
            _balanceTo(a0, a1, daiAmount, usdcAmount, 0);
            (f0, f1) = _mint(liquidity, 0);
            remaining = _skirkUP();
            emit Comp(f0, f1, remaining);
        }
    }

    ///@notice Will deposit slightly less or equal than the specified liquidity.
    function _addxSkirk(uint256 xSkirk, uint256 amount2Deposit) internal returns(uint256, uint256, uint256){
        (uint160 sqrtP,,,,,,) = IUniswapV3Pool(DAI_USDC_POOL).slot0();
        require(sqrtP <= tu_SqrtP && sqrtP >= tl_SqrtP, "MG: IR");
        uint128 liquidity = _getLiquidity(amount2Deposit);
        (uint256 a0, uint256 a1) = LiquidityMath.getAmountsForLiquidity(sqrtP, tl_SqrtP, tu_SqrtP, liquidity);
        require(a0 + _usdcToBase(a1) >= amount2Deposit - amount2Deposit.mulDiv(5, 100), "PC: LL");
        if(a1 == 0){
            // Mint already!
            (uint256 used0, uint256 used1) = _mint(liquidity, 1);
            return (used0, used1, xSkirk - used0);
        }
        a0 = a0 > 0 ? (a0 + 1) : 0;
        a1 = a1 > 0 ? (a1 + 1) : 0;
        (uint256 xSkirkRemaining,) = _balanceTo(a0, a1, xSkirk, 0, 1);
        (uint256 x, uint256 y) = _mint(liquidity, 1);
        emit AddxSkirk(x, y, xSkirkRemaining - x);
        return (x, y, xSkirkRemaining - x);
    }

    ////////////////////////////////////////////////////////////////////////////////////
    //                              Private external calls:                           //
    ////////////////////////////////////////////////////////////////////////////////////

    function _skirkUP() internal returns(uint256 xSkirkOut){
        uint256 usdc = IERC20(USDC).balanceOf(address(this));
        if(usdc > 0){
            // Swap all USDC to DAI.
            uint256 dy = _usdcToBase(usdc);
            _usdcForDai(usdc, dy - dy.mulDiv(5, 10_000), 0);
        }
        uint256 dai = IERC20(DAI).balanceOf(address(this));
        xSkirkOut = IxSkirk(xSKIRK).exactIn(dai);
    }

    ///@notice Gets required Balances:
    function _balanceTo(uint256 daiTarget, uint256 usdcTarget, uint256 daiAmount, uint256 usdcAmount, uint8 flag) internal returns(uint256, uint256){
        if(daiAmount > daiTarget && usdcAmount < usdcTarget){                // Dai surplus, we swap dai for usdc.
            uint256 diff = usdcTarget - usdcAmount;
            uint256 dInTermsOfDai = _usdcToBase(diff);
            uint256 amountIn = dInTermsOfDai + (dInTermsOfDai.mulDiv(5, 10_000));
            if(flag == 1){
                IxSkirk(xSKIRK).burn(amountIn);
            }
            uint256 usdcReceived = _daiForUsdc(amountIn, diff, usdcAmount);
            return (daiAmount - amountIn, usdcReceived + usdcAmount);
        } else if(daiAmount < daiTarget && usdcAmount > usdcTarget){         // Usdc surplus, we swap usdc for dai. 
            uint256 diff = daiTarget - daiAmount;
            uint256 amountIn = _daiToUsdcBase(diff + diff.mulDiv(5, 10_000));
            uint256 daiReceived = _usdcForDai(amountIn, diff, daiAmount);
            return(daiReceived + daiAmount, usdcAmount - amountIn);
        }
        revert("MG: BB");
    }

    ///@notice Curve 3pool swapping DAI for USDC:
    function _daiForUsdc(uint256 daiIn, uint256 minUsdc, uint256 usdcBalance) internal returns(uint256 usdcOut){
        // Params( i: tokenIn, j: tokenOut, dx: amountIn, min_dy: minUsdc)  dai: 0, usdc: 1
        ICurve(CRV3POOL).exchange(0, 1, daiIn, minUsdc);
        usdcOut = IERC20(USDC).balanceOf(address(this)) - usdcBalance;
        require(usdcOut >= minUsdc, "HG: SF1");
    }

    ///@notice Curve 3pool swapping DAI for USDC:
    function _usdcForDai(uint256 usdcIn, uint256 minDai, uint256 daiBalance) internal returns(uint256 daiOut){
        // Params( i: tokenIn, j: tokenOut, dx: amountIn, min_dy: minUsdc)  dai: 0, usdc: 1
        ICurve(CRV3POOL).exchange(1, 0, usdcIn, minDai);
        daiOut = IERC20(DAI).balanceOf(address(this)) - daiBalance;
        require(daiOut >= minDai, "HG: SF");
    }

    function _mint(uint128 liquidity, uint8 flag) internal returns(uint256, uint256){
        if(flag == 1){
            bytes memory flagData = abi.encode(flag);
            return IUniswapV3Pool(DAI_USDC_POOL).mint(
                address(this),
                TL,
                TU,
                liquidity,
                flagData
            );
        }
        return IUniswapV3Pool(DAI_USDC_POOL).mint(
            address(this),
            TL,
            TU,
            liquidity,
            ""
        );
    }

    function _claim() internal returns(uint256 a0, uint256 a1){
        IUniswapV3Pool(DAI_USDC_POOL).burn(TL, TU, 0);
        (a0, a1) = IUniswapV3Pool(DAI_USDC_POOL).collect(
            address(this),
            TL,
            TU,
            2**128-1,
            2**128-1
        );
    }

    ////////////////////////////////////////////////////////////////////////////////////
    //                              Pure Internal calls:                              //
    ////////////////////////////////////////////////////////////////////////////////////

    ///@notice Since deposits will only happen if the current tick is between our hardcoded values, the l calculation can be assumed.
    ///@dev The current tick must be inside the position grid, otherwise this assumption breaks.
    function _getLiquidity(uint256 amountToDepositInDai) private pure returns(uint128 liquidity){
        liquidity = SafeCast.toUint128(((amountToDepositInDai - amountToDepositInDai.mulDiv(1, 100)) / 2) / 1e2);
    }

    function _daiToUsdcBase(uint256 daiAmount) private pure returns(uint256){
        if(daiAmount <= 1e12){
            return 2;
        }
        return daiAmount / 1e12;
    }

    function _usdcToBase(uint256 usdcAmount) internal pure returns(uint256 usdcInBase){
        usdcInBase = usdcAmount * 1e12;
    }

    ////////////////////////////////////////////////////////////////////////////////////
    //                                      Callbacks:                                //
    ////////////////////////////////////////////////////////////////////////////////////

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata flag
    ) external {
        require(msg.sender == DAI_USDC_POOL, "C: NP");

        uint8 decodedFlag = 0;
        if (flag.length > 0) {
            decodedFlag = abi.decode(flag, (uint8));
        }
        if (amount0Owed > 0){
            if(decodedFlag == 1){
                IxSkirk(xSKIRK).burn(amount0Owed);
            }
            IERC20(DAI).safeTransfer(msg.sender, amount0Owed);
        }
        if (amount1Owed > 0){
            IERC20(USDC).safeTransfer(msg.sender, amount1Owed);
        }
    }
}