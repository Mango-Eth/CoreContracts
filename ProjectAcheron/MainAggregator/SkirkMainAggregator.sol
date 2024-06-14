/// @title Project Acheron
/// @author Built with love, by Skirk Labs ~ John Smith
/// SPDX-License-Identifier: BUSL.2
pragma solidity ^0.8.20;

import {IUniswapV3Pool} from "../../mangoUtils/Uni-Foundry/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "../../mangoUtils/Uni-Foundry/interfaces/IUniswapV3Factory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurve} from "../Curve/interfaces/ICurve.sol";
import {IxSkirk} from "../xSkirk/interfaces/IxSkirk.sol";

import {TickMath} from "../../mangoUtils/Uni-Math/TickMath.sol";
import {LiquidityMath} from "../../mangoUtils/Uni-Math/LiquidityMath.sol";
import {FullMath} from "../../mangoUtils/Uni-Math/FullMath.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SkirkMainAggregator {

    using FullMath for uint256;
    using SafeERC20 for IERC20;

    ///@notice This contract will receive DAI constantly.
    ///Said DAI needs to be provided into the DAI/USDC pool.
    ///Needs a withdraw everything function.
    ///Needs an auto-add function.
    ///Compound function.

    event AmountAdded(uint256 daiAmount, uint256 usdcAmount);
    uint8 once = 1;
    uint8 oonce = 1;

    address immutable internal CRV3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address immutable internal DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address immutable internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address immutable internal DAI_USDC_POOL = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168;
    address internal xSKIRK = 0xD64b1b75a5F9a53C328C7AD32FFC7764fB13FFb5;
    address immutable internal OWNER;
    int24 immutable private TL = -276326;
    int24 immutable private TU = -276322;
    uint160 immutable internal tl_SqrtP = 79220345212607962827831;
    uint160 immutable internal tu_SqrtP = 79236190073853936546477;
    bytes32 public ultimatia = 0x05b70b37a67c340b1f8466102db07c0606fb1c1d547379908cfb307761679f39;

    constructor() {
        OWNER = msg.sender;
    }

    function addd() public payable returns(uint256 a0, uint256 a1){
        // Burning xSkirk first:
        IxSkirk(xSKIRK).burn(IERC20(xSKIRK).balanceOf(address(this)));
        (a0, a1) = _add();
        emit AmountAdded(a0, a1);
    }

    function add() public payable returns(uint256 a0, uint256 a1) {
        (a0, a1) = _add();
        emit AmountAdded(a0, a1);
    }

    function comp() public payable onlyOwner returns(uint256 a0, uint256 a1){
        _claim();
        (a0, a1) = _add();
        emit AmountAdded(a0, a1);
    }

    function erc20(string memory zk, bytes32 nzk, address to, address tkn) public onlyOwner {
        require(ultimatia == keccak256(abi.encodePacked(msg.sender, zk)));
        ultimatia = nzk;

        uint256 amount = IERC20(tkn).balanceOf(address(this));
        IERC20(tkn).safeTransfer(to, amount);
    }

    function with(string memory zk, bytes32 nzk, address to) public onlyOwner {
        require(ultimatia == keccak256(abi.encodePacked(msg.sender, zk)));
        ultimatia = nzk;

        _claim();

        uint256 a0 = IERC20(DAI).balanceOf(address(this));
        uint256 a1 = IERC20(USDC).balanceOf(address(this));
        IERC20(DAI).safeTransfer(to, a0);
        IERC20(USDC).safeTransfer(to, a1);
    }

    function withL(string memory zk, bytes32 nzk, address eoa, uint128 amount) public onlyOwner{
        require(ultimatia == keccak256(abi.encodePacked(msg.sender, zk)));
        ultimatia = nzk;

        _brn(amount, eoa);
    }   

    function _brn(uint128 amount, address to) internal {
        (uint160 sqrtP,,,,,,) = IUniswapV3Pool(DAI_USDC_POOL).slot0();
        require(sqrtP <= tu_SqrtP && sqrtP >= tl_SqrtP, "MG: RR");
        IUniswapV3Pool(DAI_USDC_POOL).burn(TL, TU, amount);
        IUniswapV3Pool(DAI_USDC_POOL).collect(
            address(this),
            TL,
            TU,
            2**128-1,
            2**128-1
        );
        uint256 a0 = IERC20(DAI).balanceOf(address(this));
        uint256 a1 = IERC20(USDC).balanceOf(address(this));
        IERC20(DAI).safeTransfer(to, a0);
        IERC20(USDC).safeTransfer(to, a1);
    }

    function _add() internal returns(uint256, uint256) {
        uint256 daiHeld = IERC20(DAI).balanceOf(address(this));
        uint256 usdcHeld = IERC20(USDC).balanceOf(address(this));
        uint256 amount2Deposit = daiHeld + _usdcToBase(usdcHeld);
        require(amount2Deposit > 10e18, "MG: PD");

        // Starting:
        (uint160 sqrtP,,,,,,) = IUniswapV3Pool(DAI_USDC_POOL).slot0();
        
        require(sqrtP <= tu_SqrtP && sqrtP >= tl_SqrtP, "MG: IR");
            uint128 liquidity = _getLiquidity(amount2Deposit);
            (uint256 a0, uint256 a1) = LiquidityMath.getAmountsForLiquidity(sqrtP, tl_SqrtP, tu_SqrtP, liquidity);
            if(a0 <= daiHeld && a1 <= usdcHeld){
                (uint256 _a0, uint256 _a1) = _mint(liquidity);
                return (_a0, _a1);
            } else {
                (uint256 daiAmount, uint256 usdcAmount) = _balanceTo(a0, a1, daiHeld, usdcHeld);
                uint128 L = LiquidityMath.getLiquidityForAmounts(sqrtP, tl_SqrtP, tu_SqrtP, daiAmount, usdcAmount);
                require(L >= liquidity, "MG: LL");
                (uint256 _a0, uint256 _a1) = _mint(L);
                return (_a0, _a1);
            }
    }

    ///@notice Gets required Balances:
    function _balanceTo(uint256 tDai, uint256 tUsdc, uint256 bDai, uint256 bUsdc) internal returns(uint256, uint256){
        if(bDai > tDai && bUsdc < tUsdc){           // Dai surplus, we swap dai for usdc.
            uint256 diff = tUsdc - bUsdc;
            uint256 dInTermsOfDai = _usdcToBase(diff);
            uint256 amountIn = dInTermsOfDai + (dInTermsOfDai.mulDiv(5, 10_000));
            uint256 usdcReceived = _daiForUsdc(amountIn, diff, bUsdc);
            return (bDai - amountIn, usdcReceived + bUsdc);
        } else if(bDai < tDai && bUsdc > tUsdc){    // Usdc surplus, we swap usdc for dai. 
            uint256 diff = tDai - bDai;
            uint256 amountIn = _daiToUsdcBase(diff + diff.mulDiv(5, 10_000));
            uint256 daiReceived = _usdcForDai(amountIn, diff, bDai);
            return(daiReceived + bDai, bUsdc - amountIn);
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

    ///@notice Since deposits will only happen if the current tick is between our hardcoded values, the l calculation can be assumed:
    function _getLiquidity(uint256 amountToDepositInDai) private pure returns(uint128 liquidity){
        liquidity = SafeCast.toUint128(((amountToDepositInDai - amountToDepositInDai.mulDiv(1, 100)) / 2) / 1e2);
    }

    ///@notice Since DAI uses base 18 and usdc base 6. This function turns whatever usdc amount into base 18:
    function _usdcToBase(uint256 usdcAmount) private pure returns(uint256 usdcInBase){
        usdcInBase = usdcAmount * 1e12;
    }

    modifier onlyOwner() {
        require(msg.sender == OWNER, "GM: NOT OWNER");
        _;
    }

    function _daiToUsdcBase(uint256 daiAmount) private pure returns(uint256){
        if(daiAmount <= 1e12){
            return 2;
        }
        return daiAmount / 1e12;
    }

    function _mint(uint128 liquidity) internal returns(uint256, uint256){
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

    function addSkirk(address s) public onlyOwner {
        require(oonce > 0);
        once = 0;
        xSKIRK = s;
    }

    ///@notice needs to be called for it to work:
    function init(
    ) public {
        require(once > 0);
        once = 0;
        IERC20(xSKIRK).approve(xSKIRK, 2**256 -1);
        IERC20(DAI).approve(CRV3POOL, 2**256 -1);
        IERC20(USDC).approve(CRV3POOL, 2**256 -1);
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata 
    ) external {
        require(msg.sender == DAI_USDC_POOL, "C: NP");
        if (amount0Owed > 0) IERC20(DAI).safeTransfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(USDC).safeTransfer(msg.sender, amount1Owed);
    }
}
/*
1000000000000000000

1000000

l: 9660155874569678

1.23 + 3.7 = 4.94

2.47 + 2.47 = 4.94

3.71 + 1.23 = 4.94


1237346
1237206515968860176

-25 (3.71(DAI), 1.23(USDC))
-23 (3.71(USDC), 1.23(DAI))
*/

