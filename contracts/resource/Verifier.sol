// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../lib/Utils.sol";
import "../lib/Constants.sol";
import "../lib/Structs.sol";

interface IVerifier{
    function register(
        string memory network,
        uint chain,
        address contractC, 
        string memory functionC) 
        external;

    function resolve(
        string memory network, 
        uint chain) 
        external view 
        returns(address, string memory);
}

contract Verifier is IVerifier{
    
    mapping(bytes32 => Structs.VerifyInfo) verifiedNetworks;
    
    modifier checkUri(bytes memory network){
        require(checkUriExist(Utils.hash(network)), Constants.ERROR_VER_URI_NOT_FOUND);
        _;
    }
    function checkUriExist(bytes32 hash)internal view returns(bool){
        return Utils.checkAddress(verifiedNetworks[hash].contractC) 
                && Utils.checkBytes(verifiedNetworks[hash].functionC) ;
    }

    function register(
        string memory network,
        uint chain,
        address contractC, 
        string memory functionC)
        external {
            bytes32 hash = Utils.hash(abi.encodePacked(Constants.PREFIX,  network, chain));
            verifiedNetworks[hash] = Structs.VerifyInfo(contractC, functionC);
    }
    
    function resolve(
        string memory network, 
        uint chain) 
        external view 
        checkUri(abi.encodePacked(Constants.PREFIX, network, chain))
        returns(address, string memory){
            bytes32 hash = Utils.hash(abi.encodePacked(Constants.PREFIX, network, chain));
            return (verifiedNetworks[hash].contractC, verifiedNetworks[hash].functionC);    
    }
}