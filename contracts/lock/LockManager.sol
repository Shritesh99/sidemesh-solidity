// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../sidemesh/Sidemesh.sol";

contract LockManager is Sidemesh {

    mapping(bytes32 => Lock)public locks;
    mapping(bytes32 => string[])public writeKeySet;
    mapping(bytes32 => string[])public wSet;

    constructor(string memory network) Sidemesh(network){}

    function checkTimeoutLock(Lock memory lock, uint cur, bool isValid, uint status, uint ttlTime)internal view returns(bool){
        string memory network = getNetwork();
        
        require(Lib.equals(lock.primaryPrepareTxId.uri.network, network), ERROR_SECONDARY_LOCK);
        require(lock.primaryPrepareTxId.uri.chain == block.chainid, ERROR_WRONG_CHAIN);

        require(isValid, ERROR_NO_PRIMARY_TX);

        require(
            status != uint(GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED) &&
            status != uint(GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED),
            ERROR_INVALID_TX_STATUS);
        
        require(ttlTime < cur, ERROR_INVALID_TIME);

        return true;
    }
    
    function putWriteKey(string memory key)internal{
        string memory network = getNetwork();
        bytes32 xidKey = Lib.hash(abi.encodePacked(PREFIX, network, block.chainid, msg.sender));

        writeKeySet[xidKey].push(key);
    }

    function putLock(bytes32 hash, Lock memory lock)external{
        locks[hash] = lock;
    }

    function getWriteKeySetLength(bytes32 hash)external view returns(uint){
        return writeKeySet[hash].length;
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
        external view returns(Lock memory){
            bytes32 keyHash = Lib.hash(abi.encodePacked(key));

            require(checkTimeoutLock(locks[keyHash], cur, isValid, status, ttlTime), ERROR_EXPIRED_LOCK);

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
            bytes32 keyHash = Lib.hash(abi.encodePacked(key));

            if(!locks[keyHash].isValid){
                locks[keyHash] = lockDeserializer(value);
                return;
            }

            require(checkTimeoutLock(locks[keyHash], cur, isValid, status, ttlTime), ERROR_EXPIRED_LOCK);
        }

    function putLockedStateWithPrimaryLock(
        string memory key,
        bytes memory value,
        uint cur,
        bool isValid,
        uint status,
        uint ttlTime)
        external{
            string memory network = getNetwork();
            bytes32 keyHash = Lib.hash(abi.encodePacked(key));
            
            TransactionID memory primaryPrepareTxId = TransactionID(URI(network, block.chainid), msg.sender);
            
            if(!locks[keyHash].isValid){
                Lock memory lock;
                lock.updatingState = value;
                lock.primaryPrepareTxId = primaryPrepareTxId;
                lock.isValid = true;
                locks[keyHash] = lock;
                putWriteKey(key);
                return;
            }

            require(checkTimeoutLock(locks[keyHash], cur, isValid, status, ttlTime), ERROR_EXPIRED_LOCK);
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
            bytes32 keyHash = Lib.hash(abi.encodePacked(key));
            TransactionID memory primaryPrepareTxId = TransactionID(URI(primaryNetwork, primaryChain), primaryTxSender);
            
            if(!locks[keyHash].isValid){
                Lock memory lock;
                lock.updatingState = value;
                lock.primaryPrepareTxId = primaryPrepareTxId;
                lock.isValid = true;
                locks[keyHash] = lock;
                putWriteKey(key);
                return;
            }

            require(checkTimeoutLock(locks[keyHash], cur, isValid, status, ttlTime), ERROR_EXPIRED_LOCK);
        }
}