/// @title Base Vars stored here.
/// @author Built with love, by Skirk Labs ~ John Smith

/// SPDX-License-Identifier: BUSL.2
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IUniswapV3Pool} from "../../mangoUtils/Uni-Foundry/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "../../mangoUtils/Uni-Foundry/interfaces/IUniswapV3Factory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IxSkirk} from "../xSkirk/interfaces/IxSkirk.sol";

import {TickMath} from "../../mangoUtils/Uni-Math/TickMath.sol";
import {LiquidityMath} from "../../mangoUtils/Uni-Math/LiquidityMath.sol";
import {FullMath} from "../../mangoUtils/Uni-Math/FullMath.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AcheronBase is ERC721 {

    uint256 immutable internal MIN_AMOUNT = 1e17;

    ///@notice Marks the median of Acherons Lp range.
    uint96 immutable internal MEDIAN_POINT = 10_000e18;

    uint160 immutable internal LG = 2378033000839262826893220031138;  // 903

    uint160 immutable internal UG = 11203153538136334211227743944704; // 19995
                     
    ///@notice 900 in q96.
    uint160 immutable internal tl_SqrtP = 2373597069249974917302093533021;

    ///@notice 20k in q96.
    uint160 immutable internal tu_SqrtP = 11182265215894369642182094599515;

    ///@notice 900 in Tick.
    int24 immutable internal TL = 68000;

    ///@notice 15k in Tick.
    int24 immutable internal TU = 99000;

    address immutable internal xSKIRK_WETH_POOL;

    address immutable internal xSKIRK;

    address immutable internal UniFactory;
    address immutable internal DAI;
    address immutable internal WETH;        
    address immutable internal SKIRK_AGGREGATOR;
    address immutable internal dai_weth;

    /// @notice Burn incentive will cummulate over time and reduce to 0 when someone burns.
    uint256 public burnIncentive;

    uint256 immutable internal MIN_COMPOUND = 7e18;    

    ///@notice Id counter
    uint16 internal ID;

    uint8 internal ONCE;

    ///@notice Last possible id
    uint16 immutable internal LAST_ID;
    uint16 internal FIRST_ID = 777;

    ///@notice Consider making internal
    uint256 public rewardCoefficient;

    /// @notice Keeps track of each id's rewardCoefficient portion. Also turn internal
    mapping(uint256 => uint256) public assetRewardBasis;

    constructor(
        address _xSkirkWeth,
        address _xSkirk,
        address _dai,
        address _weth,
        address _skirkAggregator,
        address _dai_weth,
        address _uniFactory
    ) ERC721("Project Acheron", "ACHERON") {
        xSKIRK_WETH_POOL = _xSkirkWeth;
        xSKIRK = _xSkirk;
        DAI = _dai;
        WETH = _weth;
        SKIRK_AGGREGATOR = _skirkAggregator;
        dai_weth = _dai_weth;
        UniFactory = _uniFactory;
        ID = 777;
        LAST_ID = 7777;
    }

    function initialize() external {
        require(ONCE == 0);
        IERC20(DAI).approve(xSKIRK, 2**256 -1);
        ONCE = 1;
    }
}