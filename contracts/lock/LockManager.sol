// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../sidemesh/Sidemesh.sol";

contract LockManager is Sidemesh {

    function checkTimeoutLock(Lock memory lock, uint cur)internal view returns(bool){
        string memory network = getNetwork();
        
        require(Lib.equals(lock.primaryPrepareTxId.uri.network, network), ERROR_SECONDARY_LOCK);
        require(lock.primaryPrepareTxId.uri.chain == block.chainid, ERROR_WRONG_CHAIN);
        
        bytes32 xidKey = Lib.hash(abi.encodePacked(
                PREFIX,
                lock.primaryPrepareTxId.uri.network,
                lock.primaryPrepareTxId.uri.chain,
                lock.primaryPrepareTxId.sender
                ));
        
        require(globalTransactionStatuses[xidKey].isValid, ERROR_NO_PRIMARY_TX);

        require(
            globalTransactionStatuses[xidKey].status != GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED &&
            globalTransactionStatuses[xidKey].status != GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED,
            ERROR_INVALID_TX_STATUS);

        require(globalTransactions[xidKey].ttlTime < cur, ERROR_INVALID_TIME);
        return true;
    }
    
    function putWriteKey(string memory key)internal{
        string memory network = getNetwork();
        bytes32 xidKey = Lib.hash(abi.encodePacked(PREFIX, network, block.chainid, msg.sender));

        writeKeySet[xidKey].push(key);
    }

    function getStateMaybeLocked(
        string memory key,
        uint cur)
        external view {// return error
            // bytes32 keyHash = Lib.hash(abi.encodePacked(key));

            // require(!locks[keyHash].isValid, ERROR_NO_LOCK);
            // require(checkTimeoutLock(locks[keyHash], cur), ERROR_EXPIRED_LOCK);
        }

    function putStateMaybeLocked(
        string memory key,
        bytes memory value,
        uint cur)
        external view{
            // bytes32 keyHash = Lib.hash(abi.encodePacked(key));

            // // values -> Lock ?
            // // if(!locks[keyHash].isValid)
            // //     locks[keyHash] = value;

            // require(!locks[keyHash].isValid, ERROR_NO_LOCK);
            // require(checkTimeoutLock(locks[keyHash], cur), ERROR_EXPIRED_LOCK);
        }

    function putLockedStateWithPrimaryLock(
        string memory key,
        bytes memory value,
        uint cur)
        external{
            // string memory network = getNetwork();
            // bytes32 keyHash = Lib.hash(abi.encodePacked(key));
            
            // TransactionID memory primaryPrepareTxId = TransactionID(URI(network, block.chainid), msg.sender);
            
            // if(!locks[keyHash].isValid){
            //     Lock memory lock;
            //     lock.updatingState = value;
            //     lock.primaryPrepareTxId = primaryPrepareTxId;
            //     lock.isValid = true;
            //     locks[keyHash] = lock;
            //     putWriteKey(key);
            //     return;
            // }
            // putWriteKey(key);
            // //locks[keyHash]

            // require(!locks[keyHash].isValid, ERROR_NO_LOCK);
            // require(checkTimeoutLock(locks[keyHash], cur), ERROR_EXPIRED_LOCK);
        }

    function putLockedStateWithNetworkLock(
        string memory key,
        bytes memory value,
        string memory primaryNetwork,
        uint primaryChain,
        string memory primaryTxID,
        uint cur)
        internal{
            
        }
}