// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../lib/Lib.sol";

import "../util/Structs.sol";
import "../util/Modifiers.sol";
import "../util/Constants.sol";

contract Sidemesh is Modifiers, Structs, Constants {

    string network;

    mapping(bytes32 => GlobalTransactionStatus) globalTransactionStatuses;
    mapping(bytes32 => GlobalTransaction) globalTransactions;
    mapping(bytes32 => Lock) locks;
    mapping(bytes32 => string[]) writeKeySet;
    mapping(bytes32 => string[]) wSet;

    function getNetwork()
        internal view
        checkEmpty(network, ERROR_NETWORK) returns(string memory){
            return network;
    }

    function setNetwork(string memory networkC)public{
        network = networkC;
    }


}