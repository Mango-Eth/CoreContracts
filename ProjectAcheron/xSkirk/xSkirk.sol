/// @title Project Acheron
/// @author Built with love, by Skirk Labs ~ John Smith
/// SPDX-License-Identifier: BUSL.2
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract xSkirk is ERC20Burnable {

    using SafeERC20 for IERC20;

    address immutable internal ACHERON;
    address immutable internal DAI;
    address immutable internal SKIRK_MAIN;

    uint256 private constant COLLATERALIZATION_RATE = 11000;
    uint256 private constant FEE_BASIS_POINTS = 100;
    uint256 private constant MIN_DAI = 1e14;
    uint256 private constant MIN_xSKIRK = 1e14;

    uint256 private constant BLOCKCOUNTER = 7000;   // Slightly more than 1 day.
    mapping(uint256 => uint256) internal res;

    constructor(
        address _projectAcheron,
        address _dai,
        address _skirkMain
    ) ERC20("xSkirk", "XSKIRK") {
        ACHERON = _projectAcheron;
        DAI = _dai;
        SKIRK_MAIN = _skirkMain;
    }

    ///@notice The amount specified in xSkirk will the be the amount minted.
    function exactSkirkOut(uint256 _xSkirk) external returns(uint256 _daiRequired){
        uint256 fee;
        (_daiRequired, fee) = _getSkirkForDai(_xSkirk);
        require(_daiRequired >= MIN_DAI, "SKRK: LU");

        IERC20(DAI).safeTransferFrom(msg.sender, SKIRK_MAIN, fee);
        IERC20(DAI).safeTransferFrom(msg.sender, address(this), _daiRequired - fee);

        _mint(msg.sender, _xSkirk);
    }

    ///@notice The amount specified in DAI will be the amount spent.
    function exactIn(uint256 _dai) external returns(uint256 _xSkirk){
        uint256 fee;
        require(_dai >= MIN_DAI, "SKRK: LA");
        (_xSkirk, fee) = _daiToSkirk(_dai);

        IERC20(DAI).safeTransferFrom(msg.sender, SKIRK_MAIN, fee);
        IERC20(DAI).safeTransferFrom(msg.sender, address(this), _dai - fee);

        _mint(msg.sender, _xSkirk);
    }

    /// @notice This way of burning allows to exchange xSkirk for DAI in a 1.1 - 0.01% ratio.
    function getBounty(uint256 _skirkAmount, uint256 id) public {
        require(IERC721(ACHERON).ownerOf(id) == msg.sender, "SKRK: ZS");
        bool r = _handleId(id);
        require(r, "SKRK: TIM");
        require(_skirkAmount >= MIN_xSKIRK, "SKRK: MN");
        (uint256 collateralizedDAI,) = _getCollateralizedDAI(_skirkAmount);
        super.burn(_skirkAmount);
        IERC20(DAI).safeTransfer(msg.sender, collateralizedDAI);
    }

    /// @notice Burning grants a one to one exchange rate of xSkirk and DAI.
    function burn(uint256 _skirkAmount) public override { 
        require(_skirkAmount >= MIN_xSKIRK, "SKRK: MN");
        (uint256 collateralizedDAI, uint256 diff) = _getCollateralizedDAI(_skirkAmount);
        super.burn(_skirkAmount);
        require(_skirkAmount == collateralizedDAI - diff, "Precision");
        IERC20(DAI).safeTransfer(msg.sender, _skirkAmount);
        IERC20(DAI).safeTransfer(SKIRK_MAIN, diff);
    }

    /// @notice Returns the amount of xSkirk you would get for provided DAI amount.
    function _daiToSkirk(uint256 _daiAmount) internal pure returns(uint256 skirkAmount, uint256 fee){
        fee = (_daiAmount * FEE_BASIS_POINTS) / 10_000;
        uint256 netDAIAmount = _daiAmount - fee;
        skirkAmount = (netDAIAmount * 10_000) / COLLATERALIZATION_RATE;
    }

    /// @notice Returns the total DAI required to mint the desired xSkirk amount, including the fee.
    function _getSkirkForDai(uint256 _skirkAmount) internal pure returns(uint256 daiAmount, uint256 fee) {
        uint256 collateralizedAmount = (_skirkAmount * COLLATERALIZATION_RATE) / 10_000;
        // First, calculate the DAI amount without considering the fee
        uint256 daiWithoutFee = collateralizedAmount;
        // Then, calculate what the total would be with the fee included
        daiAmount = (daiWithoutFee * 10_000) / (10_000 - FEE_BASIS_POINTS);
        // The fee is the difference between the total amount with fee and the amount without the fee
        fee = daiAmount - daiWithoutFee;
    }

    function daiToSkirk(uint256 _dai) external pure returns(uint256 skirkOut){
        (skirkOut,) = _daiToSkirk(_dai);
    }

    function getSkirkForDai(uint256 _skirk) external pure returns(uint256 daiRequired){
        uint256 extra;
        (daiRequired, extra) = _getSkirkForDai(_skirk);
        daiRequired = daiRequired;
    }

    function previewBounty(uint256 _skirk) external pure returns(uint256 dai2Receive){
        uint256 extra;
        (dai2Receive, extra) = _getSkirkForDai(_skirk);
        dai2Receive = dai2Receive - extra;
    }

    /// @notice Returns the DAI amount at a 110% collateralization rate for the given xSkirk amount, and the difference between this amount and the given xSkirk amount.
    /// @param _skirkAmount The amount of xSkirk for which to calculate the collateralization.
    /// @return collateralizedDAI The amount of DAI required for 110% collateralization of the given xSkirk amount.
    /// @return difference The difference between the collateralized DAI amount and the given xSkirk amount.
    function _getCollateralizedDAI(uint256 _skirkAmount) internal pure returns (uint256 collateralizedDAI, uint256 difference) {
        collateralizedDAI = (_skirkAmount * COLLATERALIZATION_RATE) / 10_000;
        difference = collateralizedDAI - _skirkAmount;
    }

    ///@notice Handles mapping managing for new/re-used nft ids for claiming bounties.
    function _handleId(uint256 id) internal returns(bool){
        uint256 timestamp = res[id];
        uint256 currentBlock = block.number;
        if(timestamp > 0){
            require(currentBlock > timestamp, "SKRK: TMR");
            res[id] = block.number + BLOCKCOUNTER;
            return true;
        } else if(timestamp == 0){
            res[id] = block.number + BLOCKCOUNTER;
            return true;
        }
        revert("NA");
    }

    /// @notice The total debt, will be the same as the totalSupply from xSkirk
    function getTotalDebt() public view returns(uint256){
        return totalSupply();
    }
}