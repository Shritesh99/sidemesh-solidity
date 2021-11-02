// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../lib/Lib.sol";

import "../util/Structs.sol";
import "../util/Constants.sol";

contract Verifier is Structs, Constants{
    
    mapping(bytes32 => VerifyInfo) verifiedNetworks;
    
    modifier checkUri(bytes memory network){
        require(checkUriExist(Lib.hash(network)), VER_URI_NOT_FOUND);
        _;
    }
    function checkUriExist(bytes32 hash)internal view returns(bool){
        return Lib.checkAddress(verifiedNetworks[hash].contractC) 
                && Lib.checkBytes(verifiedNetworks[hash].functionC) ;
    }

    function register(
        string memory network,
        uint chain,
        address contractC, 
        string memory functionC) 
        external {
            bytes32 hash = Lib.hash(abi.encodePacked(PREFIX,  network, chain));
            verifiedNetworks[hash] = VerifyInfo(contractC, functionC);
    }
    
    function resolve(
        string memory network, 
        uint chain) 
        external view 
        checkUri(abi.encodePacked(PREFIX, network, chain))
        returns(address, string memory){
            bytes32 hash = Lib.hash(abi.encodePacked(PREFIX, network, chain));
            return (verifiedNetworks[hash].contractC, verifiedNetworks[hash].functionC);    
    }
}