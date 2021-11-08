// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../lib/Enums.sol";

library Structs{
    
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
        Enums.GlobalTransactionStatusType status;
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
}