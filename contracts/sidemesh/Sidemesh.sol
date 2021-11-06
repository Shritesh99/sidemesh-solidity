// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../lib/Lib.sol";

import "../util/Structs.sol";
import "../util/Modifiers.sol";
import "../util/Constants.sol";

contract Sidemesh is Modifiers, Structs, Constants {

    string network;

    function getNetwork()
        internal view
        checkEmpty(network, ERROR_NETWORK) returns(string memory){
            return network;
    }

    function setNetwork(string memory networkC)public{
        network = networkC;
    }


}