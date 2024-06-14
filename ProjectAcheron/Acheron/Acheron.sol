/// @title Project Acheron
/// @author Built with love, by Skirk Labs ~ John Smith
/// This token will serve as a main pillar of integration for upcoming projects.
/// Most upcoming projects will remain decentralized, therefore the low granulairty of ERC721's
/// serve as enough accounting for share holders. If future governance protocols are released,
/// this ERC721 will be wrapped for an ERC20 amount of tokens, to further integrate with future projects.

// SPDX-License-Identifier: BUSL.2 
pragma solidity ^0.8.20;

import "./AcheronCompounder.sol";

contract Acheron is AcheronCompounder {

    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using TickMath for int24;

    /// @notice Logs the amount of rewards spread to all holders
    event RebasedRewards(uint256 xSkirkAmount);

    constructor(
        address _xSkirkWeth,
        address _xSkirk,
        address _dai,
        address _weth,
        address _skirkAggregator,
        address _dai_weth,
        address _uniFactory
    ) AcheronCompounder(
        _xSkirkWeth, _xSkirk, _dai, _weth, _skirkAggregator, _dai_weth, _uniFactory
    ){}

    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using TickMath for int24;
    using FullMath for uint256;

    uint256 internal counter;       // For tests only

    /// @notice Mint function to obtain "Crimson Shards". 
    /// The "payable" modifier is only added to make the function call save gas.
    function mint(bool fee) external payable returns(uint256 id){

        // State effets
        uint256 amount2Pay = 1000e18;   
        IERC20(xSKIRK).safeTransferFrom(msg.sender, address(this), amount2Pay);
        
        uint8 flag = fee ? 1 : 0;
        uint256 remaining = _aggregate_(350e18, 0, 350e18, flag);

        require(remaining <= 50e18, "Mango");
        IERC20(xSKIRK).safeTransfer(SKIRK_AGGREGATOR, amount2Pay - (350e18 - remaining));

        id = counter;   // For tests only
        counter++;      // For tests only

        // id = uint256(ID);                        // Commenting this, removes minting limit.
        // ID++;
        // require(ID <= LAST_ID + 1, "A: MM");     // Commenting this, removes minting limit.

        assetRewardBasis[id] = rewardCoefficient;
        _mint(msg.sender, id);
        return id;
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

    function burnAcheron(uint256 _ensurance, uint256 tokenId) external payable {
        uint256 amount = burnIncentive;
        require(msg.sender == ownerOf(tokenId), "A: NO");
        require(amount >= _ensurance, "A: FR");
        burnIncentive = 0;
        _burn(tokenId);
        FIRST_ID++;                                         // Reducing totalSupply
        IERC20(xSKIRK).safeTransfer(msg.sender, amount);
    }

    // event EmitCompoundingAmount(uint256);
    // event EmitSumFees(uint256);
    // event EmitAmounts2Compound(uint256, uint256);
    // event SkirkRemaining_(uint256);
    function compound(bool fee) external payable returns(uint256 xSkirkOut){
        require(balanceOf(msg.sender) > 0, "A: B0"); // Must be acheron holder.
        uint8 flag = fee ? 1 : 0;
        // Strong TWAP price:
        uint256 wethPrice = _getWethPrice();
        uint256 dust = IERC20(WETH).balanceOf(address(this));
        uint256 wethAmount;
        uint256 skirkAmount;
        (wethAmount, skirkAmount) = _claim();
        // emit EmitAmounts2Compound(wethAmount, skirkAmount);
        wethAmount = wethAmount + dust;
        uint256 wethAmountInDai = _wethToDai(wethPrice, wethAmount);
        uint256 sum = wethAmountInDai + skirkAmount;
        // emit EmitSumFees(sum);
        // uint256 amount2Compound = (sum * 30) / 100;
        uint256 amount2Compound = sum.mulDiv(30, 100);
        require(amount2Compound >= MIN_COMPOUND, "A: MC");  // more than 7e18
        // Compounding all WETH we have
        // emit EmitAmounts2Compound(wethAmount, skirkAmount);
        uint256 skirkRemaining = _aggregate_(skirkAmount, wethAmount, amount2Compound, flag);
        // emit SkirkRemaining_(skirkRemaining);
        require(skirkRemaining < sum && 
            skirkRemaining + skirkRemaining.mulDiv(5, 100) >= sum - amount2Compound, "A: CA");         // Cant be more than that we started with.
        uint256 amount2Rebase = skirkRemaining.mulDiv(84, 100);
        uint256 burnIncentive = skirkRemaining.mulDiv(8, 100);
        uint256 caller = skirkRemaining.mulDiv(8, 100);
        require(skirkRemaining >= amount2Rebase + burnIncentive + caller, "A: SM");

        _rebase(amount2Rebase, burnIncentive);
        IERC20(xSKIRK).safeTransfer(msg.sender, caller);
        xSkirkOut = caller;
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
        emit RebasedRewards(_amount);
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
        return "https:/Project_Acheron/";
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