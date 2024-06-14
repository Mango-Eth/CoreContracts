/// SPDX-License-Identifier: Built by Mango
pragma solidity ^0.8.20;

import {Create3} from "../../mangoUtils/Create3.sol"; 
import {Acheron_Core} from "./Acheron_Core.sol";

contract AcheronDeployerMainnet {

    struct Params {
        address WETH_SKIRK_POOL;
        address xSkirk;
    }

    address immutable internal OWNER;

    constructor() {
        OWNER = msg.sender;
    }

    /////////////////////////////////////////////////////
    //              External:                          //
    /////////////////////////////////////////////////////

    function deploy(
        string memory _salt_Acheron,
        Params memory p
    ) external onlyOwner {
        bytes32 salt_Acheron = keccak256(abi.encodePacked(_salt_Acheron));
        address acheron = _address3(salt_Acheron);

        bytes memory bytecode = type(Acheron_Core).creationCode;
        bytes memory args = abi.encode(p.WETH_SKIRK_POOL, p.xSkirk);
        bytecode = bytes.concat(bytecode, args);
        _deploy(acheron, bytecode, 0, salt_Acheron);
    }

    function address3(
        string memory _str
    ) external view returns(address){
        return _address3(keccak256(abi.encodePacked(_str)));
    }

    /////////////////////////////////////////////////////
    //              Internal-Pure-Modifier:            //
    /////////////////////////////////////////////////////

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

    modifier onlyOwner {
        require(OWNER == msg.sender, "AD: NOPE");
        _;
    }

}

/*
    Deploying Acheron:

    0.5) Deploy the SkirkProgenitorAggregator
    1) First both the AcheronDeployer & the xSkirkDeployer must be deployed to mainnet.
    2) Then test out salt, until we get a xSkirk address which is LARGER than the current WETH address.
    3) With said xSkirk address create a WETH/xSKIRK pool with a sqrtPrice of the current WETH price.
    4) Deploy both xSKirk & Acheron in their respective deployment scripts by passing the previously used salt.
*/