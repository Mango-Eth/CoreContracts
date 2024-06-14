//SPDX-License-Identifier: Built by Mango
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockERC20} from "../../mangoUtils/MockERC20.sol";

contract CurveMock {

    using SafeERC20 for IERC20;

    address DAI;
    address USDC;

    constructor(
        address _dai,
        address _usdc
    ) {
        DAI = _dai;
        USDC = _usdc;
    }

    // Params( i: tokenIn, j: tokenOut, dx: amountIn, min_dy: minUsdc)  dai: 0, usdc: 1
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external {
        if(i == 0 && j == 1){   // DAI in, USDC out
            IERC20(DAI).safeTransferFrom(msg.sender, address(this), dx);
            MockERC20(USDC).mint(min_dy);
            IERC20(USDC).safeTransfer(msg.sender, min_dy);
        } else if(i == 1 && j == 0){    // USDC in, DAI out
            IERC20(USDC).safeTransferFrom(msg.sender, address(this), dx);
            MockERC20(DAI).mint(min_dy);
            IERC20(DAI).safeTransfer(msg.sender, min_dy);
        } else{
            revert("asdf");
        }
    }


}