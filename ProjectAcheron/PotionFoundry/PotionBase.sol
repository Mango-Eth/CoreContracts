/// @title Base Vars stored here.
/// @author Built with love, by Skirk Labs ~ John Smith

/// SPDX-License-Identifier: BUSL.2
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IUniswapV3Pool} from "../../mangoUtils/Uni-Foundry/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "../../mangoUtils/Uni-Foundry/interfaces/IUniswapV3Factory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IxSkirk} from "../xSkirk/interfaces/IxSkirk.sol";
import {ICurve} from "../Curve/interfaces/ICurve.sol";

import {TickMath} from "../../mangoUtils/Uni-Math/TickMath.sol";
import {LiquidityMath} from "../../mangoUtils/Uni-Math/LiquidityMath.sol";
import {FullMath} from "../../mangoUtils/Uni-Math/FullMath.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Chainlink
import {AggregatorV3Interface} from "../Chainlink/AggregatorV3Interface.sol";

contract PotionBase is ERC721 {

    ///@notice Id counter
    uint16 internal ID;
    uint160 immutable internal tl_SqrtP = 79220345212607962827831;
    int24 immutable internal TU = -276322;
    int24 immutable internal TL = -276326;
    uint160 immutable internal tu_SqrtP = 79236190073853936546477;

    // Mainnet contracts:
    address immutable internal SKIRK_AGGREGATOR;    // On deployment can be hardcoded
    address immutable internal xSKIRK;
    address immutable internal CRV3POOL;
    address immutable internal DAI;
    address immutable internal USDC;
    address immutable internal DAI_USDC_POOL;
    address immutable internal ACHERON;

    /// @notice Burn incentive will cummulate over time and reduce to 0 when someone burns.
    uint256 public burnIncentive;

    uint256 immutable internal MIN_COMPOUND = 7e18;    

    uint8 internal ONCE;

    ///@notice Last possible id
    uint16 immutable internal LAST_ID;
    uint16 internal FIRST_ID = 777;

    ///@notice Consider making internal
    uint256 public rewardCoefficient;

    /// @notice Keeps track of each id's rewardCoefficient portion. Also turn internal
    mapping(uint256 => uint256) public assetRewardBasis;

    constructor(
        address _mainAggregator,
        address _xSkirk,
        address crv,
        address _dai,
        address _usdc,
        address _dai_usdc,
        address _acheron
    ) ERC721("Project Acheron", "ACHERON") {
        ID = 777;
        LAST_ID = 7777;
        ONCE = 1;
        
        SKIRK_AGGREGATOR = _mainAggregator;
        xSKIRK = _xSkirk;
        CRV3POOL = crv;
        DAI = _dai;
        USDC = _usdc;
        DAI_USDC_POOL = _dai_usdc;
        ACHERON = _acheron;
    }

    function initialize() external {
        require(ONCE >0);
        ONCE = 0;
        IERC20(DAI).approve(CRV3POOL, 2**256 -1);
        IERC20(USDC).approve(CRV3POOL, 2**256 -1);
        IERC20(DAI).approve(xSKIRK, 2**256 -1);
    }
}