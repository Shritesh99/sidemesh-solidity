// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

library Enums{
    enum GlobalTransactionStatusType{
        PRIMARY_TRANSACTION_PREPARED,
        PRIMARY_TRANSACTION_COMMITTED,
        PRIMARY_TRANSACTION_CANCELED
    }

    function checkCanceledOrCommiteded(uint status)internal pure returns(bool){
        return status != uint(GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED) &&
            status != uint(GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED);
    }
}