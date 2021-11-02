// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../lib/Lib.sol";

import "../util/Structs.sol";
import "../util/Constants.sol";

contract Register is Structs, Constants{

    mapping(bytes32 => string) registeredNetworks;

    modifier checkUri(bytes memory network){
        require(checkUriExist(Lib.hash(network)), REG_URI_NOT_FOUND);
        _;
    }
    function checkUriExist(bytes32 hash)internal view returns(bool){
        return Lib.checkBytes(registeredNetworks[hash]);
    }
    
    function register(
        string memory network,
        uint chain,
        string memory connection) 
        external {
            bytes memory uri = abi.encodePacked(PREFIX, network, chain);
            registeredNetworks[Lib.hash(uri)] = connection;

            emit SIDE_MESH_RESOURCE_REGISTERED_EVENT(network, chain, Lib.toBytes(connection));
    }
    
    function resolve(
        string memory network, 
        uint chain) 
        external view
        checkUri(abi.encodePacked(PREFIX, network, chain))
        returns(string memory){
            bytes32 hash = Lib.hash(abi.encodePacked(PREFIX, network, chain));
            return registeredNetworks[hash];    
    }
}