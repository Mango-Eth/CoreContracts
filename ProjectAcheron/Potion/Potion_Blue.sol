/// @title Green_Potion
/// @author Built with love, by Skirk Labs ~ John Smith
/// SPDX-License-Identifier: BUSL.2
pragma solidity ^0.8.20;

import "./Potion_Compounder.sol";

contract Potion_Blue is Potion_Compounder {

    using FullMath for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    event RemainingSkirkSent(uint256);
    function mint() public returns(uint256, uint256, uint256){
        uint256 amount2Pay = uint256(BLUE);
        IERC20(xSKIRK).safeTransferFrom(msg.sender, address(this), amount2Pay);
        (uint256 a0, uint256 a1, uint256 skirkRemaining) = _addxSkirk(amount2Pay, amount2Pay.mulDiv(35, 100));
        IERC20(xSKIRK).safeTransfer(SKIRK_AGGREGATOR, skirkRemaining);

        uint256 id = uint256(ID);
        ID++;

        require(ID <= LAST_ID + 1, "A: MM");
        assetRewardBasis[id] = rewardCoefficient;
        _mint(msg.sender, id);

        emit RemainingSkirkSent(skirkRemaining);
        return (a0, a1, skirkRemaining);
    }

    function claimReward(uint256 assetId) external {
        _claimReward(assetId);
    }

    function claimAll(uint256[] calldata assetId) external {
        uint256 length = assetId.length;
        for(uint256 i; i < length; i++){
            _claimReward(assetId[i]);
        }
    }

    /// @notice The compounding mechanism will aggregate rewards through this function.
    /// @dev This function can also act as a portal to spread more rewards to holders.
    function rebase(uint256 _amount, uint256 _burnIncentive) external payable {
        uint256 totalAmount = _amount + _burnIncentive;
        require(_burnIncentive >= 1, "A: BA");
        IERC20(xSKIRK).safeTransferFrom(msg.sender, address(this), totalAmount);
        _rebase(_amount, _burnIncentive);
    }

    function burnPotion(uint256 _ensurance, uint256 tokenId) external payable {
        require(msg.sender == ownerOf(tokenId), "A: NO");
        require(burnIncentive >= _ensurance, "A: FR");
        uint256 amount = burnIncentive;
        burnIncentive = 0;
        _burn(tokenId);
        FIRST_ID++;                                         // Reducing totalSupply
        IERC20(xSKIRK).safeTransfer(msg.sender, amount);
    }

    event Sum(uint256, uint256);
    function compound() external payable {  // Only acheron holders are allowed to call!
        _claim();
        uint256 daiAmount = IERC20(DAI).balanceOf(address(this));
        uint256 usdcAmount = IERC20(USDC).balanceOf(address(this));
        uint256 sum = daiAmount + _usdcToBase(usdcAmount);
        uint256 amount2Spend = sum.mulDiv(30, 100);
        emit Sum(sum, amount2Spend);
        (uint256 a0, uint256 a1, uint256 r) = _comp(daiAmount, usdcAmount, amount2Spend);
        require(a0 + _usdcToBase(a1) >= amount2Spend - amount2Spend.mulDiv(5, 100), "PB: 2L");
        uint256 amount2Rebase = r.mulDiv(84, 100);
        uint256 burnAndCall = r.mulDiv(8, 1000);
        require(amount2Rebase + burnAndCall + burnAndCall <= r, "PB: RU");
        _rebase(amount2Rebase, burnAndCall);
        IERC20(xSKIRK).safeTransfer(msg.sender, burnAndCall);
    }

    ////////////////////////////////////////////////////////////////////////
    //                              INTERNAL                              //
    ////////////////////////////////////////////////////////////////////////

    ///@notice Internal rebasing from compounds:
    function _rebase(uint256 _amount, uint256 _burnIncentive) internal {
        require(_amount > 1e10, "A: ZA");
        uint256 totalAssets = uint256(ID - FIRST_ID);
        require(totalAssets > 0, "A: ZER0");
        rewardCoefficient += _amount / totalAssets;
        burnIncentive += _burnIncentive;
    }

    /// @notice Allows for claiming of xSkirk which is sent to this contract via "update".
    function _claimReward(uint256 assetId) internal {
        uint256 reward = _calculateReward(assetId);
        assetRewardBasis[assetId] = rewardCoefficient;
        IERC20(xSKIRK).safeTransfer(ownerOf(assetId), reward);
    }

    /// @notice This function calculates the Delta which corresponds to the investor for his time of minting together with
    /// all rewards that entred afterwards.
    function _calculateReward(uint256 assetId) internal view returns(uint256) {
        require(_exists(assetId), "R: DE");
        uint256 rewardDelta = rewardCoefficient - assetRewardBasis[assetId];
        return rewardDelta;
    }

    function _baseURI() internal pure override returns(string memory){
        return "https:/Project_Acheron/Potion";
    }

    ////////////////////////////////////////////////////////////////////////
    //                              VIEW-READ                             //
    ////////////////////////////////////////////////////////////////////////

    function currentId() external view returns(uint16){
        return ID;
    }

    function calculateReward(uint256 assetId) external view returns(uint256){
        return _calculateReward(assetId);
    }
}