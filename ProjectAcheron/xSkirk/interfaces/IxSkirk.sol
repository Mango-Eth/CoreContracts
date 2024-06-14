// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IxSkirk {
    function burn(uint256 amount) external;
    function exactIn(uint256 daiIn) external returns(uint256);
}   
    