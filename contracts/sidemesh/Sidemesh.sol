// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../lib/Utils.sol";
import "../lib/Constants.sol";

interface ISidemesh{
    function getNetwork()external view returns(string memory);
    function setNetwork(string memory networkC)external;
}

contract Sidemesh is ISidemesh {

    string network;

    function getNetwork()external view returns(string memory){
            require(Utils.isEmpty(network), Constants.ERROR_NETWORK);
            return network;
    }

    function setNetwork(string memory networkC)public{
        network = networkC;
    }
}