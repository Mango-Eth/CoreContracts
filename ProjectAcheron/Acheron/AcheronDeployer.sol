// SPDX-License-Identifier: Built by Mango
pragma solidity ^0.8.20;

import {Create3} from "../../mangoUtils/Create3.sol";   
import {xSkirk} from "../xSkirk/xSkirk.sol";
import {Acheron} from "./Acheron.sol";

contract AcheronDeployer {

    struct Params {
        address _xSkirkWeth;
        address _xSkirk;
        address _dai;
        address _weth;
        address _skirkAggregator;
        address _dai_weth;
        address _uniFactory;
    }

    address OWNER;

    constructor() {
        OWNER = msg.sender;
    }

    function deploy(
        Params memory p,
        string memory salt
    ) external onlyOwner {
        bytes32 _hash = keccak256(abi.encodePacked(salt));
        address acheronAddress = _address3(_hash);
        bytes memory bytecode = type(Acheron).creationCode;
        bytes memory args = abi.encode(p._xSkirkWeth, p._xSkirk, p._dai, p._weth, p._skirkAggregator, p._dai_weth, p._uniFactory);
        bytecode = bytes.concat(bytecode, args);
        _deploy(acheronAddress, bytecode, 0, _hash);
    }

    function _deploy(
        address _checkAddress,
        bytes memory _createionCode,
        uint256 _value,
        bytes32 salt
    ) private {
        address a = Create3.create3(
            salt,
            _createionCode,
            _value
        );
        require(a == _checkAddress);
    }

    function _address3(
        bytes32 salt
    ) private view returns(address) {
        return Create3.addressOf(salt);
    }

    function address3(
        string memory _str
    ) external view returns(address){
        return _address3(keccak256(abi.encodePacked(_str)));
    }

    modifier onlyOwner {
        require(OWNER == msg.sender, "AD: NOPE");
        _;
    }

}






// pragma solidity ^0.8.20;

// import {Create3} from "../../mangoUtils/Create3.sol";   
// import {xSkirk} from "../xSkirk/xSkirk.sol";
// import {Acheron} from "./Acheron.sol";

// /*
// Mainnet params:
// Acheron { address _daiWeth, address _xSkirkWeth, address _xSkirk }

// xSkirk { address _projectAcheron, address _dai, address _owner }

// Test params:
// Acheron { address _daiWeth, address _xSkirkWeth, address _xSkirk, address 
//     _skirkSwapFactory, address _UniFactory, address _dai, address _weth, address _SkirkAggregator }

// xSkirk { address _projectAcheron, address _dai, address _owner }
// */
// contract AcheronDeployer {

//     struct Params {
//         address DAI_WETH_POOL;
//         address WETH_SKIRK_POOL;
//         address dai;
//         address weth;
//         address SkirkFactory;
//         address UniFactory;
//         address SkirkAggregator;    // Owner
//     }

//     address immutable internal OWNER;

//     constructor() {
//         OWNER = msg.sender;
//     }

//     function deploy(
//         string memory _salt_xSkirk,
//         string memory _salt_Acheron,
//         Params memory p
//     ) external onlyOwner {
//         bytes32 salt_Acheron = keccak256(abi.encodePacked(_salt_Acheron));
//         bytes32 salt_xSkirk = keccak256(abi.encodePacked(_salt_xSkirk));
//         address acheron = _address3(salt_Acheron);
//         address _xSkirk = _address3(salt_xSkirk);

//         bytes memory bytecode = type(xSkirk).creationCode;
//         bytes memory args = abi.encode(acheron, p.dai, p.SkirkAggregator);
//         bytecode = bytes.concat(bytecode, args);
//         _deploy(_xSkirk, bytecode, 0, salt_xSkirk);
        
//         {
//             bytecode = type(Acheron).creationCode;
//             args = abi.encode(p.DAI_WETH_POOL, p.WETH_SKIRK_POOL, _xSkirk, p.SkirkFactory, p.UniFactory, p.dai, p.weth, p.SkirkAggregator);
//             bytecode = bytes.concat(bytecode, args);
//             _deploy(acheron, bytecode, 0, salt_Acheron);
//         }
//     }

    // function _deploy(
    //     address _checkAddress,
    //     bytes memory _createionCode,
    //     uint256 _value,
    //     bytes32 salt
    // ) private {
    //     address a = Create3.create3(
    //         salt,
    //         _createionCode,
    //         _value
    //     );
    //     require(a == _checkAddress);
    // }

    // function _address3(
    //     bytes32 salt
    // ) private view returns(address) {
    //     return Create3.addressOf(salt);
    // }

    // function address3(
    //     string memory _str
    // ) external view returns(address){
    //     return _address3(keccak256(abi.encodePacked(_str)));
    // }

    // modifier onlyOwner {
    //     require(OWNER == msg.sender, "AD: NOPE");
    //     _;
    // }
// }