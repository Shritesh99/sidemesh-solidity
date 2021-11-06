// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../sidemesh/Sidemesh.sol";

import "../resource/Verifier.sol";
import "../resource/Register.sol";
import "../lock/LockManager.sol";

contract GlobalTransactionManager is Sidemesh {
    
    Verifier verifier;
    Register registry;
    LockManager lockManager;

    NetworkTransaction[] networkPrepareTxs;
    NetworkTransaction[] networkConfirmTxs;

    mapping(bytes32 => GlobalTransactionStatus) globalTransactionStatuses;
    mapping(bytes32 => GlobalTransaction) globalTransactions;

    constructor (
        address _registery,
        address _verifier,
        address _lockManager){
            registry = Register(_registery);
            verifier = Verifier(_verifier);
            lockManager = LockManager(_lockManager);
        }

    function getDataForCheckTimeout(
        string memory network,
        uint chain,
        address sender)
        external view returns(bool, uint, uint){
            bytes32 xidKey = Lib.hash(abi.encodePacked(PREFIX, network, chain, sender));
            
            require(globalTransactionStatuses[xidKey].isValid, ERROR_NO_PRIMARY_TX);
            
            return(
                globalTransactionStatuses[xidKey].isValid,
                uint(globalTransactionStatuses[xidKey].status),
                globalTransactions[xidKey].ttlTime
                );
        }
    
    function getNetworkTxs(bytes32 xidKey, bool porc)internal{
        if(porc){
            for(uint i=0; i<globalTransactions[xidKey].networkPrepareTxsLength;i++){
                networkPrepareTxs.push(globalTransactions[xidKey].networkPrepareTxs[i]);
            }
        }else{
            for(uint i=0; i<globalTransactions[xidKey].networkConfirmTxsLength;i++){
                networkConfirmTxs.push(globalTransactions[xidKey].networkConfirmTxs[i]);
            }
        }
    }

    function startGlobalTransaction(
        uint ttlHeight,
        uint ttlTime)
        external 
        checkPositive(ttlHeight, ERROR_TTLHEIGHT)
        checkNonZero(ttlTime, ERROR_TTLTIME){
            string memory network = getNetwork();
            bytes32 xid = Lib.hash(abi.encodePacked(PREFIX, network, block.chainid, msg.sender));

            GlobalTransaction storage globalTx = globalTransactions[xid];
            globalTx.primaryPrepareTxId = TransactionID(URI(network, block.chainid), msg.sender);
            globalTx.networkPrepareTxsLength = 0;
            globalTx.networkConfirmTxsLength = 0;
            globalTx.ttlHeight = ttlHeight;
            globalTx.ttlTime = ttlTime;
            globalTx.isValid = true;
        }

    function registerNetworkTransaction(
        string memory network,
        uint chain,
        address contractC, 
        string memory functionC, 
        string[] memory args)
        external{
            string memory primaryNetwork = getNetwork();
            bytes32 xid = Lib.hash(abi.encodePacked(PREFIX, primaryNetwork, block.chainid, msg.sender));

            NetworkTransaction memory txId;
            txId.txId = TransactionID(URI(network, chain), msg.sender);
            txId.invocation = Invocation(contractC, functionC, args);

            globalTransactions[xid].networkPrepareTxs[globalTransactions[xid].networkPrepareTxsLength] = txId;
            globalTransactions[xid].networkPrepareTxsLength++;
        }
    
    function preparePrimaryTransaction(
        string memory functionC) 
        external{
            string memory network = getNetwork();
            bytes32 xidKey = Lib.hash(abi.encodePacked(PREFIX, network, block.chainid, msg.sender));
            
            Invocation memory invocation;
            invocation.functionC = functionC;
            invocation.args = new string[](1);
            invocation.args[0] = Lib.toString(abi.encodePacked(msg.sender));
            
            NetworkTransaction memory txId;
            txId.txId = TransactionID(URI(network, block.chainid), msg.sender);
            txId.invocation = invocation;

            globalTransactions[xidKey].primaryConfirmTx = txId;

            GlobalTransactionStatus memory globalTxStatus;
            globalTxStatus.primaryPrepareTxId = globalTransactions[xidKey].primaryPrepareTxId;
            globalTxStatus.status = GlobalTransactionStatusType.PRIMARY_TRANSACTION_PREPARED;
            globalTxStatus.isValid = true;
            
            globalTransactionStatuses[xidKey] = globalTxStatus;

            if(lockManager.getWriteKeySetLength(xidKey) > 0){
                for(uint i=0; i<lockManager.getWriteKeySetLength(xidKey); i++){
                    lockManager.putWSet(xidKey, lockManager.writeKeySet(xidKey, i));
                }
            }

            Invocation memory queryGlobalTxInvocation;
            queryGlobalTxInvocation.functionC = QUERYGLOBALTXSTATUS;
            
            getNetworkTxs(xidKey, true);
            getNetworkTxs(xidKey, false);

            emit PrimaryTransactionPreparedEvent(
                globalTransactions[xidKey].primaryPrepareTxId,
                globalTransactions[xidKey].primaryConfirmTx,
                queryGlobalTxInvocation,
                networkPrepareTxs,
                networkConfirmTxs
                );
            
            delete networkPrepareTxs;
            delete networkConfirmTxs;
        }

    function confirmPrimaryTransaction(
            address primaryPrepareTxSender,
            string[][] memory networkTxRes
        )external{
            string memory network = getNetwork();
            bytes32 xidKey = Lib.hash(abi.encodePacked(PREFIX, network, block.chainid, primaryPrepareTxSender));

            require(globalTransactionStatuses[xidKey].isValid, ERROR_NO_PRIMARY_TX);

            require(
                globalTransactionStatuses[xidKey].status == GlobalTransactionStatusType.PRIMARY_TRANSACTION_PREPARED,
                ERROR_DUPLICATE_TX_STATUS);

            require(globalTransactions[xidKey].isValid, ERROR_NO_GLOBAL_TX);

            require(
                globalTransactions[xidKey].networkPrepareTxsLength == networkTxRes.length,
                ERROR_DEPENDENT_TX
            );

            uint numVerified = 0;
            for(uint i=0;i<networkTxRes.length;i++){
                globalTransactions[xidKey].networkPrepareTxs[i].txId.sender = Lib.toAddress(networkTxRes[i][2]);
                globalTransactions[xidKey].networkPrepareTxs[i].proof = networkTxRes[i][3];

                (address contractC, string memory functionC) = verifier.resolve(networkTxRes[i][0], Lib.toUint(networkTxRes[i][1]));
                require(!Lib.checkAddress(contractC), ERROR_CONTRACT);
                require(!Lib.isEmpty(functionC), ERROR_FUNCTION);

                if(!Lib.isEmpty(networkTxRes[i][3])){
                    (bool success,) = contractC.call(abi.encodeWithSignature(functionC, networkTxRes[i][2], networkTxRes[i][3]));
                    require(success, ERROR_FAILED);
                    numVerified++;
                }
            }
            if (numVerified == globalTransactions[xidKey].networkPrepareTxsLength) {
                globalTransactionStatuses[xidKey].status = GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED;
            } else {
                globalTransactionStatuses[xidKey].status = GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED;
            }
            
            
            if(lockManager.getWSetLength(xidKey) > 0){
                for(uint i=0; i<lockManager.getWSetLength(xidKey); i++){
                    bytes32 hash = Lib.hash(abi.encodePacked(lockManager.wSet(xidKey, i)));
                    
                    (,bytes memory prevState,
                    bytes memory updatingState,
                    bool isValid) = lockManager.locks(hash);
                    
                    require(isValid, ERROR_NO_LOCK);
                    
                    if(globalTransactionStatuses[xidKey].status == GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED){
                        lockManager.putLock(hash, lockDeserializer(updatingState));    
                    }else if(globalTransactionStatuses[xidKey].status == GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED){
                        lockManager.putLock(hash, lockDeserializer(prevState)); 
                    }
                }
            }
            
            for(uint i=0; i<globalTransactions[xidKey].networkPrepareTxsLength;i++){
                NetworkTransaction memory networkConfirmTx;
                TransactionID memory txId;
                txId.uri = URI(
                            globalTransactions[xidKey].networkPrepareTxs[i].txId.uri.network,
                            globalTransactions[xidKey].networkPrepareTxs[i].txId.uri.chain);
                networkConfirmTx.txId = txId;

                Invocation memory invocation;
                invocation.contractC = globalTransactions[xidKey].networkPrepareTxs[i].invocation.contractC;
                invocation.functionC = globalTransactions[xidKey].networkPrepareTxs[i].invocation.functionC;
                invocation.args = new string[](5);
                invocation.args[0] = Lib.toString(abi.encodePacked(globalTransactions[xidKey].networkPrepareTxs[i].txId.sender));
                invocation.args[1] = Lib.toString(abi.encodePacked(uint(globalTransactionStatuses[xidKey].status)));
                invocation.args[2] = network;
                invocation.args[3] = Lib.toString(abi.encodePacked(block.chainid));
                invocation.args[4] = Lib.toString(abi.encodePacked(msg.sender));

                networkConfirmTx.invocation = invocation;

                globalTransactions[xidKey].networkConfirmTxs[globalTransactions[xidKey].networkConfirmTxsLength] = networkConfirmTx;
                globalTransactions[xidKey].networkConfirmTxsLength++;
            }

            getNetworkTxs(xidKey, false);

            emit PrimaryTransactionConfirmedEvent(
                TransactionID(URI(network, block.chainid), msg.sender),
                networkConfirmTxs
            );
            delete networkConfirmTxs;
        }

    function startNetworkTransaction(
        string memory primaryNetwork,
        uint primaryChain,
        string memory primaryTxID,
        string memory primaryTxProof)
        external
        checkEmpty(primaryTxProof, ERROR_PRIMARYTXPROOF){
            (address contractC, string memory functionC) = verifier.resolve(primaryNetwork, primaryChain);
            require(!Lib.checkAddress(contractC), ERROR_CONTRACT);
            require(!Lib.isEmpty(functionC), ERROR_FUNCTION);

            (bool success,) = contractC.call(abi.encodeWithSignature(functionC, primaryTxID, primaryTxProof));
            require(success, ERROR_FAILED);
        }
    
    function prepareNetworkTransaction(
        string memory primaryNetwork,
        uint primaryChain,
        address primaryTxSender,
        address globalTxQueryContract,
        string memory globalTxQueryFunc,
        string memory functionC)
        external{
            string memory network = getNetwork();
            
            TransactionID memory globalTxId = TransactionID(URI(primaryNetwork, primaryChain), primaryTxSender);
            Invocation memory globalTxQuery = Invocation(globalTxQueryContract, globalTxQueryFunc, new string[](1));
            globalTxQuery.args[0] = string(abi.encodePacked(primaryTxSender));

            bytes32 bidKey = Lib.hash(abi.encodePacked(PREFIX, network, block.chainid, msg.sender));
            if(lockManager.getWriteKeySetLength(bidKey) > 0){
                for(uint i=0; i<lockManager.getWriteKeySetLength(bidKey); i++){
                    lockManager.putWSet(bidKey, lockManager.writeKeySet(bidKey, i));
                }
            }
            
            Invocation memory invocation;
            invocation.functionC = functionC;
            invocation.args = new string[](1);
            invocation.args[0] = Lib.toString(abi.encodePacked(msg.sender));
            
            NetworkTransaction memory networkConfirmTx;
            networkConfirmTx.txId = TransactionID(URI(network, block.chainid), msg.sender);
            networkConfirmTx.invocation = invocation;

            emit NetworkTransactionPreparedEvent(
                globalTxId,
                globalTxQuery,
                networkConfirmTx
                );
        }

    function confirmNetworkTransaction(
        address networkPrepareTxSender,
        uint globalTxStatus,
        string memory primaryNetwork,
        uint primaryChain,
        address primaryConfirmTxSender,
        string memory primaryConfirmTxProof)
        external{
            (address contractC, string memory functionC) = verifier.resolve(primaryNetwork, primaryChain);
            require(!Lib.checkAddress(contractC), ERROR_CONTRACT);
            require(!Lib.isEmpty(functionC), ERROR_FUNCTION);

            require(!Lib.isEmpty(primaryConfirmTxProof), ERROR_NO_PRIMARY_CONFIRM_TX_PROOF);

            (bool success,) = contractC.call(abi.encodeWithSignature(functionC, primaryConfirmTxSender, primaryConfirmTxProof));
            require(success, ERROR_NO_PRIMARY_CONFIRM_TX);

            string memory network = getNetwork();
            bytes32 bidKey = Lib.hash(abi.encodePacked(PREFIX, network, block.chainid, networkPrepareTxSender));

            if(lockManager.getWSetLength(bidKey) > 0){
                for(uint i=0; i<lockManager.getWSetLength(bidKey); i++){
                    bytes32 hash = Lib.hash(abi.encodePacked(lockManager.wSet(bidKey, i)));

                    (,bytes memory prevState,
                    bytes memory updatingState,
                    bool isValid) = lockManager.locks(hash);

                    require(isValid, ERROR_NO_LOCK);
                    
                    if(globalTxStatus == uint(GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED)){
                        lockManager.putLock(hash, lockDeserializer(updatingState));    
                    }else if(globalTxStatus == uint(GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED)){
                        lockManager.putLock(hash, lockDeserializer(prevState)); 
                    }
                }
            }
    }
}