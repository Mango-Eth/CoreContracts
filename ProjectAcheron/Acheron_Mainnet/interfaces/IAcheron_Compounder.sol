// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAcheron_Compounder {

    struct MintCallbackData {
        address token0;
        address token1;
        uint24 fee;
    }

    struct SwapCallbackData {
        address tokenIn;
        address tokenOut;
        uint24 fee;
    }

    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint256 amount;
    }
}