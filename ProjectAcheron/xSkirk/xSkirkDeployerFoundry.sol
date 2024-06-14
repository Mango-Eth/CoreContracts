/// SPDX-License-Identifier: Built by Mango
pragma solidity ^0.8.20;

import {Create3} from "../../mangoUtils/Create3.sol"; 
import {xSkirk} from "./xSkirk.sol";

contract xSkirkDeployerFoundry {

    struct Params {
        address _projectAcheron;
        address _dai;
        address _owner;
    }

    address immutable internal OWNER;

    constructor() {
        OWNER = msg.sender;
    }

    /////////////////////////////////////////////////////
    //              External:                          //
    /////////////////////////////////////////////////////

    function deploy(
        bytes32 salt,
        Params memory p
    ) external onlyOwner {
        bytes32 _hash = salt;
        address skirkAddress = _address3(_hash);
        bytes memory bytecode = type(xSkirk).creationCode;
        bytes memory args = abi.encode(p._projectAcheron, p._dai, p._owner);
        bytecode = bytes.concat(bytecode, args);
        _deploy(skirkAddress, bytecode, 0, _hash);
    }

    function address3(
        string memory _str
    ) external view returns(address){
        return _address3(keccak256(abi.encodePacked(_str)));
    }

    function address3(
        bytes32 _slt
    ) external view returns(address){
        return _address3(_slt);
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