// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../lib/Utils.sol";
import "../lib/Constants.sol";
import "../lib/Enums.sol";
import "../lib/Structs.sol";

import "../sidemesh/Sidemesh.sol";

interface ILockManager{
    
    function getStateMaybeLocked(
        string memory key,
        uint cur,
        bool isValid,
        uint status,
        uint ttlTime)
        external view returns(Structs.Lock memory);
    
    function putStateMaybeLocked(
        string memory key,
        bytes memory value,
        uint cur,
        bool isValid,
        uint status,
        uint ttlTime)
        external;

    function putLockedStateWithPrimaryLock(
        string memory key,
        bytes memory value,
        uint cur,
        bool isValid,
        uint status,
        uint ttlTime)
        external;

    function putLockedStateWithNetworkLock(
        string memory key,
        bytes memory value,
        string memory primaryNetwork,
        uint primaryChain,
        address primaryTxSender,
        uint cur,
        bool isValid,
        uint status,
        uint ttlTime)
        external;
}

interface ILockManagerGlobalTransaction{
    function getWSet(bytes32 xidKey, uint i)external view returns(string memory);
    function getWSetLength(bytes32 hash)external view returns(uint);
    function getWriteKeySet(bytes32 xidKey, uint i)external view returns(string memory);
    function getWriteKeySetLength(bytes32 hash)external view returns(uint);
    function getLock(bytes32 hash)external view returns(Structs.Lock memory);

    function putLock(bytes32 hash, Structs.Lock memory lock)external;
    function putWSet(bytes32 hash, string memory value)external;

    function lockDeserializer(bytes memory data)external returns(Structs.Lock memory);
}

contract LockManager is ILockManager, ILockManagerGlobalTransaction{

    mapping(bytes32 => Structs.Lock)locks;
    mapping(bytes32 => string[])writeKeySet;
    mapping(bytes32 => string[])wSet;

    ISidemesh sidemesh;

    constructor(address _sidemesh){
        sidemesh = ISidemesh(_sidemesh);
    }

    function checkTimeoutLock(Structs.Lock memory lock, uint cur, bool isValid, uint status, uint ttlTime)internal view returns(bool){
        string memory network = sidemesh.getNetwork();
        
        require(Utils.equals(lock.primaryPrepareTxId.uri.network, network), Constants.ERROR_SECONDARY_LOCK);
        require(lock.primaryPrepareTxId.uri.chain == block.chainid, Constants.ERROR_WRONG_CHAIN);

        require(isValid, Constants.ERROR_NO_PRIMARY_TX);

        require(
            Enums.checkCanceledOrCommiteded(status),
            Constants.ERROR_INVALID_TX_STATUS);
        
        require(ttlTime < cur, Constants.ERROR_INVALID_TIME);

        return true;
    }

    function putWriteKey(string memory key)internal{
        string memory network = sidemesh.getNetwork();
        bytes32 xidKey = Utils.hash(abi.encodePacked(Constants.PREFIX, network, block.chainid, msg.sender));

        writeKeySet[xidKey].push(key);
    }

    function lockSerializer(Structs.Lock memory lock)internal pure returns(bytes memory){
        return abi.encodePacked(
            lock.primaryPrepareTxId.uri.network, Constants.COLON,
            lock.primaryPrepareTxId.uri.chain, Constants.COLON,
            lock.primaryPrepareTxId.sender, Constants.COLON,
            lock.prevState, Constants.COLON,
            lock.updatingState, Constants.COLON,
            Utils.toString(lock.isValid)
            );
    }
    
    bytes temp;
    
    function lockDeserializer(bytes memory data)public returns(Structs.Lock memory){
        Structs.Lock memory lock;
        Structs.TransactionID memory txID;
        Structs.URI memory uri;
        uint x = 0;
        for(uint i=0; i<data.length; i++){
            if(Utils.hash(abi.encodePacked(data[i])) == Utils.hash(abi.encodePacked(Constants.COLON))){
                if(x == 0){
                    uri.network = Utils.toString(temp);
                }
                if(x == 1){
                    uri.chain = Utils.toUint(Utils.toString(temp));
                    txID.uri = uri;
                }
                if(x == 2){
                    txID.sender = Utils.toAddress(Utils.toString(temp)); 
                    lock.primaryPrepareTxId = txID;           
                }
                if(x == 3){
                    lock.prevState = temp;
                }
                if(x == 4){
                    lock.updatingState = temp;
                }
                if(x == 5){
                    lock.isValid = Utils.stringToBool(Utils.toString(temp));
                }
                temp = "";
                x++;
            }else{
                temp.push(data[i]);
            } 
        }
        return lock;
    }

    function getLock(bytes32 hash)external view returns(Structs.Lock memory){
        return locks[hash];
    }

    function putLock(bytes32 hash, Structs.Lock memory lock)external{
        locks[hash] = lock;
    }

    function getWriteKeySet(bytes32 xidKey, uint i)external view returns(string memory){
        return writeKeySet[xidKey][i];
    }

    function getWriteKeySetLength(bytes32 hash)external view returns(uint){
        return writeKeySet[hash].length;
    }

    function getWSet(bytes32 xidKey, uint i)external view returns(string memory){
        return wSet[xidKey][i];
    }

    function getWSetLength(bytes32 hash)external view returns(uint){
        return wSet[hash].length;
    }

    function putWSet(bytes32 hash, string memory value)external{
        wSet[hash].push(value);
    }

    function getStateMaybeLocked(
        string memory key,
        uint cur,
        bool isValid,
        uint status,
        uint ttlTime)
        external view returns(Structs.Lock memory){
            bytes32 keyHash = Utils.hash(abi.encodePacked(key));

            require(checkTimeoutLock(locks[keyHash], cur, isValid, status, ttlTime), Constants.ERROR_EXPIRED_LOCK);

            return locks[keyHash];
        }

    function putStateMaybeLocked(
        string memory key,
        bytes memory value,
        uint cur,
        bool isValid,
        uint status,
        uint ttlTime)
        external{
            bytes32 keyHash = Utils.hash(abi.encodePacked(key));

            if(!locks[keyHash].isValid){
                locks[keyHash] = lockDeserializer(value);
                return;
            }

            require(checkTimeoutLock(locks[keyHash], cur, isValid, status, ttlTime), Constants.ERROR_EXPIRED_LOCK);
        }

    function putLockedStateWithPrimaryLock(
        string memory key,
        bytes memory value,
        uint cur,
        bool isValid,
        uint status,
        uint ttlTime)
        external{
            string memory network = sidemesh.getNetwork();
            bytes32 keyHash = Utils.hash(abi.encodePacked(key));
            
            Structs.TransactionID memory primaryPrepareTxId = Structs.TransactionID(Structs.URI(network, block.chainid), msg.sender);
            
            if(!locks[keyHash].isValid){
                Structs.Lock memory lock;
                lock.updatingState = value;
                lock.primaryPrepareTxId = primaryPrepareTxId;
                lock.isValid = true;
                locks[keyHash] = lock;
                putWriteKey(key);
                return;
            }

            require(checkTimeoutLock(locks[keyHash], cur, isValid, status, ttlTime), Constants.ERROR_EXPIRED_LOCK);
        }

    function putLockedStateWithNetworkLock(
        string memory key,
        bytes memory value,
        string memory primaryNetwork,
        uint primaryChain,
        address primaryTxSender,
        uint cur,
        bool isValid,
        uint status,
        uint ttlTime)
        external{
            bytes32 keyHash = Utils.hash(abi.encodePacked(key));
            Structs.TransactionID memory primaryPrepareTxId = Structs.TransactionID(Structs.URI(primaryNetwork, primaryChain), primaryTxSender);
            
            if(!locks[keyHash].isValid){
                Structs.Lock memory lock;
                lock.updatingState = value;
                lock.primaryPrepareTxId = primaryPrepareTxId;
                lock.isValid = true;
                locks[keyHash] = lock;
                putWriteKey(key);
                return;
            }

            require(checkTimeoutLock(locks[keyHash], cur, isValid, status, ttlTime), Constants.ERROR_EXPIRED_LOCK);
        }
}