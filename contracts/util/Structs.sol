// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../lib/Lib.sol";

contract Structs{
    
    string constant COLON = ":";
    uint constant ASCII_COLON = 58;
    
    enum GlobalTransactionStatusType{
        PRIMARY_TRANSACTION_PREPARED,
        PRIMARY_TRANSACTION_COMMITTED,
        PRIMARY_TRANSACTION_CANCELED
    }
    
    struct URI{
        string network;
        uint chain;
    }

    struct TransactionID{
        URI uri;
        address sender;
    }

    struct Invocation{
        address contractC;
        string functionC;
        string[] args;
    }

    struct NetworkTransaction{
        TransactionID txId;
        Invocation invocation;
        string proof;
    }

    struct GlobalTransaction{
        TransactionID primaryPrepareTxId;
        NetworkTransaction primaryConfirmTx;
        mapping(uint => NetworkTransaction) networkPrepareTxs;
        uint networkPrepareTxsLength;
        mapping(uint => NetworkTransaction) networkConfirmTxs;
        uint networkConfirmTxsLength;
        uint ttlHeight;
        uint ttlTime;
        bool isValid;  
    }

    struct GlobalTransactionStatus{
        TransactionID primaryPrepareTxId;
        TransactionID primaryConfirmTxId;
        GlobalTransactionStatusType status;
        bool isValid;
    }

    struct VerifyInfo{
        address contractC;
        string functionC;
    }

    struct Lock{
        TransactionID primaryPrepareTxId;
        bytes prevState;
        bytes updatingState;
        bool isValid;
    }

    event SIDE_MESH_RESOURCE_REGISTERED_EVENT(
        string network,
        uint chain,
        bytes connection
    );

    event PrimaryTransactionPreparedEvent(
        TransactionID PrimaryPrepareTxId,
        NetworkTransaction PrimaryConfirmTx,
        Invocation GlobalTxStatusQuery,
        NetworkTransaction[] NetworkPrepareTxs,
        NetworkTransaction[] NetworkConfirmTxs
    );

    event PrimaryTransactionConfirmedEvent(
        TransactionID PrimaryConfirmedTxId,
        NetworkTransaction[] NetworkConfirmTxs
    );

    event NetworkTransactionPreparedEvent(
        TransactionID PrimaryPrepareTxId,
        Invocation GlobalTxStatusQuery,
        NetworkTransaction ConfirmTx
    );

    function lockSerializer(Lock memory lock)internal pure returns(bytes memory){
        return abi.encodePacked(
            lock.primaryPrepareTxId.uri.network, COLON,
            lock.primaryPrepareTxId.uri.chain, COLON,
            lock.primaryPrepareTxId.sender, COLON,
            lock.prevState, COLON,
            lock.updatingState, COLON,
            Lib.toString(lock.isValid)
            );
    }
    
    bytes temp;
    
    function lockDeserializer(bytes memory data)internal returns(Lock memory){
        Lock memory lock;
        TransactionID memory txID;
        URI memory uri;
        uint x = 0;
        for(uint i=0; i<data.length; i++){
            if(Lib.hash(abi.encodePacked(data[i])) == Lib.hash(abi.encodePacked(COLON))){
                if(x == 0){
                    uri.network = Lib.toString(temp);
                }
                if(x == 1){
                    uri.chain = Lib.toUint(Lib.toString(temp));
                    txID.uri = uri;
                }
                if(x == 2){
                    txID.sender = Lib.toAddress(Lib.toString(temp)); 
                    lock.primaryPrepareTxId = txID;           
                }
                if(x == 3){
                    lock.prevState = temp;
                }
                if(x == 4){
                    lock.updatingState = temp;
                }
                if(x == 5){
                    lock.isValid = Lib.stringToBool(Lib.toString(temp));
                }
                temp = "";
                x++;
            }else{
                temp.push(data[i]);
            } 
        }
        return lock;
    }
}