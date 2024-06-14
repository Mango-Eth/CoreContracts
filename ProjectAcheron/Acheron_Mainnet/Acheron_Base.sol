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

// Chainlink
import {AggregatorV3Interface} from "../Chainlink/AggregatorV3Interface.sol";

contract Acheron_Base is ERC721 {

    uint256 immutable internal MIN_AMOUNT = 1e17;

    uint8 internal CANCEL = 1;

    ///@notice Marks the median of Acherons Lp range.
    uint96 immutable internal MEDIAN_POINT = 10_000e18;

    uint160 immutable internal LG = 2382120897181660527828393787392;  // 903
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

    address immutable internal UniFactory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address immutable internal DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address immutable internal WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;        
    address immutable internal SKIRK_AGGREGATOR = 0xC8501479803c58592eF3Be0beABBEE22e3377C08;
    address immutable internal USDT_WETH = 0x11b815efB8f581194ae79006d24E0d814B7697F6;
    address immutable internal USDC_WETH = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

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

    // ///@notice Chainlink vrf aggregator v3:
    AggregatorV3Interface internal dataFeed;

    /// @notice Keeps track of each id's rewardCoefficient portion. Also turn internal
    mapping(uint256 => uint256) public assetRewardBasis;

    constructor(
        address _xSkirkWeth,
        address _xSkirk
    ) ERC721("Project Acheron", "ACHERON") {
        xSKIRK_WETH_POOL = _xSkirkWeth;
        xSKIRK = _xSkirk;
        ID = 777;
        LAST_ID = 7777;

        dataFeed = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
    }

    function initialize() external {
        require(ONCE == 0);
        IERC20(DAI).approve(xSKIRK, 2**256 -1);
        ONCE = 1;
    }
}