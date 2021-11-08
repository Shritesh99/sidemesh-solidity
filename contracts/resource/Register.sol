// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../lib/Utils.sol";
import "../lib/Constants.sol";
import "../lib/Structs.sol";

interface IRegister{
    function register(
        string memory network,
        uint chain,
        string memory connection) 
        external;

    function resolve(
        string memory network, 
        uint chain) 
        external view
        returns(string memory);
}

contract Register is IRegister{

    mapping(bytes32 => string) registeredNetworks;

    modifier checkUri(bytes memory network){
        require(checkUriExist(Utils.hash(network)), Constants.ERROR_REG_URI_NOT_FOUND);
        _;
    }
    function checkUriExist(bytes32 hash)internal view returns(bool){
        return Utils.checkBytes(registeredNetworks[hash]);
    }
    
    function register(
        string memory network,
        uint chain,
        string memory connection) 
        external {
            bytes memory uri = abi.encodePacked(Constants.PREFIX, network, chain);
            registeredNetworks[Utils.hash(uri)] = connection;

            emit Structs.SIDE_MESH_RESOURCE_REGISTERED_EVENT(network, chain, Utils.toBytes(connection));
    }
    
    function resolve(
        string memory network, 
        uint chain) 
        external view
        checkUri(abi.encodePacked(Constants.PREFIX, network, chain))
        returns(string memory){
            bytes32 hash = Utils.hash(abi.encodePacked(Constants.PREFIX, network, chain));
            return registeredNetworks[hash];    
    }
}