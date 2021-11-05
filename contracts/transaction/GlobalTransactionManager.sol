// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../sidemesh/Sidemesh.sol";

import "../resource/Verifier.sol";
import "../resource/Register.sol";
import "../lock/LockManager.sol";

contract GlobalTransactionManager is LockManager {
    
    Verifier verifier;
    Register registry;

    constructor(
        address _registery,
        address _verifier){
            registry = Register(_registery);
            verifier = Verifier(_verifier);
        }

    function startGlobalTransaction(
        uint ttlHeight,
        uint ttlTime,
        string memory)
        external 
        checkPositive(ttlHeight, ERROR_TTLHEIGHT)
        checkNonZero(ttlTime, ERROR_TTLTIME){
            string memory network = getNetwork();
            bytes32 xid = Lib.hash(abi.encodePacked(PREFIX, network, block.chainid, msg.sender));

            GlobalTransaction memory globalTx;
            globalTx.primaryPrepareTxId = TransactionID(URI(network, block.chainid), msg.sender);
            globalTx.networkPrepareTxs = new NetworkTransaction[](0);
            globalTx.networkConfirmTxs = new NetworkTransaction[](0);
            globalTx.ttlHeight = ttlHeight;
            globalTx.ttlTime = ttlTime;
            globalTx.isValid = true;

            globalTransactions[xid] = globalTx;
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

            globalTransactions[xid].networkPrepareTxs.push(txId);
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

            if(writeKeySet[xidKey].length > 0){
                for(uint i=0; i<writeKeySet[xidKey].length; i++){
                    wSet[xidKey].push(writeKeySet[xidKey][i]);
                }
            }

            Invocation memory queryGlobalTxInvocation;
            queryGlobalTxInvocation.functionC = QUERYGLOBALTXSTATUS;

            emit PrimaryTransactionPreparedEvent(
                globalTransactions[xidKey].primaryPrepareTxId,
                globalTransactions[xidKey].primaryConfirmTx,
                queryGlobalTxInvocation,
                globalTransactions[xidKey].networkPrepareTxs,
                globalTransactions[xidKey].networkConfirmTxs
                );
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
                globalTransactions[xidKey].networkPrepareTxs.length == networkTxRes.length,
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
            if (numVerified == globalTransactions[xidKey].networkPrepareTxs.length) {
                globalTransactionStatuses[xidKey].status = GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED;
            } else {
                globalTransactionStatuses[xidKey].status = GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED;
            }
            
            
            if(wSet[xidKey].length > 0){
                for(uint i=0; i<wSet[xidKey].length; i++){
                    bytes32 hash = Lib.hash(abi.encodePacked(wSet[xidKey][i]));
                    require(locks[hash].isValid, ERROR_NO_LOCK);
                    
                    if(globalTransactionStatuses[xidKey].status == GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED){
                        locks[hash] = lockDeserializer(locks[hash].updatingState);    
                    }else if(globalTransactionStatuses[xidKey].status == GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED){
                        locks[hash] = lockDeserializer(locks[hash].prevState); 
                    }
                }
            }
            
            for(uint i=0; i<globalTransactions[xidKey].networkPrepareTxs.length;i++){
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

                globalTransactions[xidKey].networkConfirmTxs.push(networkConfirmTx);
            }

            emit PrimaryTransactionConfirmedEvent(
                TransactionID(URI(network, block.chainid), msg.sender),
                globalTransactions[xidKey].networkConfirmTxs
            );
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
            if(writeKeySet[bidKey].length > 0){
                for(uint i=0; i<writeKeySet[bidKey].length; i++){
                    wSet[bidKey].push(writeKeySet[bidKey][i]);
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

            if(wSet[bidKey].length > 0){
                for(uint i=0; i<wSet[bidKey].length; i++){
                    bytes32 hash = Lib.hash(abi.encodePacked(wSet[bidKey][i]));
                    require(locks[hash].isValid, ERROR_NO_LOCK);
                    
                    if(globalTxStatus == uint(GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED)){
                        locks[hash] = lockDeserializer(locks[hash].updatingState);    
                    }else if(globalTxStatus == uint(GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED)){
                        locks[hash] = lockDeserializer(locks[hash].prevState); 
                    }
                }
            }
    }
}