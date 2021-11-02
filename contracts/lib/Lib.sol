// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

library Lib{
    function hash(bytes memory data)internal pure returns(bytes32){
        return keccak256(data);
    }
    function toString(bytes memory data)internal pure returns(string memory){
        return string(data);
    }
    function toBytes(string memory data)internal pure returns(bytes memory){
        return bytes(data);
    }
    function equals(string memory a, string memory b)internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
    function isEmpty(string memory a)internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((""))));
    }
    function checkBytes(string memory str)internal pure returns(bool){
        return bytes(str).length != 0;
    }
    function checkAddress(address a)internal pure returns(bool){
        return a == address(a);
    }
}