/// SPDX-License-Identifier: Built by Mango
pragma solidity ^0.8.20;

import {Create3} from "../../mangoUtils/Create3.sol"; 
import {Potion_Blue} from "./Potion_Blue.sol";

contract BlueDeployer {

    struct Params {
        
    }

    address immutable internal OWNER;

    constructor() {
        OWNER = msg.sender;
    }

    /////////////////////////////////////////////////////
    //              External:                          //
    /////////////////////////////////////////////////////

    function deploy(
        string memory salt
    ) external onlyOwner {
        bytes32 hash_salt = keccak256(abi.encodePacked(salt));
        address add = _address3(hash_salt);

        bytes memory bytecode = type(Potion_Blue).creationCode;
        _deploy(add, bytecode, 0, hash_salt);
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
