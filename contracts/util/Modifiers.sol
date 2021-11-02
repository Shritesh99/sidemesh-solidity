// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../lib/Lib.sol";

contract Modifiers{
    
    modifier checkPositive(uint a, string memory err){
        require(a >= 0, err);
        _;
    }
    modifier checkNonZero(uint a, string memory err){
        require(a != 0, err);
        _;
    }
    modifier checkEmpty(string memory str, string memory err){
        require(!Lib.equals(str, ""), err);
        _;
    }
}