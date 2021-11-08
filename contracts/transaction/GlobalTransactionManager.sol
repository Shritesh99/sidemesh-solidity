// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "../lib/Utils.sol";
import "../lib/Constants.sol";
import "../lib/Enums.sol";
import "../lib/Structs.sol";

import "../sidemesh/Sidemesh.sol";
import "../resource/Verifier.sol";
import "../resource/Register.sol";
import "../lock/LockManager.sol";

interface IGlobalTransactionManager{
    function getDataForCheckTimeout(
        string memory network,
        uint chain,
        address sender)
        external view returns(bool, uint, uint);
        
    function startGlobalTransaction(
        uint ttlHeight,
        uint ttlTime)
        external;
        
    function registerNetworkTransaction(
        string memory network,
        uint chain,
        address contractC, 
        string memory functionC, 
        string[] memory args)
        external;

    function preparePrimaryTransaction(
        string memory functionC) 
        external;

    function confirmPrimaryTransaction(
            address primaryPrepareTxSender,
            string[][] memory networkTxRes
        )external;

    function startNetworkTransaction(
        string memory primaryNetwork,
        uint primaryChain,
        string memory primaryTxID,
        string memory primaryTxProof)
        external;

    function prepareNetworkTransaction(
        string memory primaryNetwork,
        uint primaryChain,
        address primaryTxSender,
        address globalTxQueryContract,
        string memory globalTxQueryFunc,
        string memory functionC)
        external;
    
    function confirmNetworkTransaction(
        address networkPrepareTxSender,
        uint globalTxStatus,
        string memory primaryNetwork,
        uint primaryChain,
        address primaryConfirmTxSender,
        string memory primaryConfirmTxProof)
        external;
}

contract GlobalTransactionManager is IGlobalTransactionManager{
    
    ISidemesh sidemesh;
    IVerifier verifier;
    IRegister registry;
    ILockManagerGlobalTransaction lockManager;

    Structs.NetworkTransaction[] networkPrepareTxs;
    Structs.NetworkTransaction[] networkConfirmTxs;

    mapping(bytes32 => Structs.GlobalTransactionStatus) globalTransactionStatuses;
    mapping(bytes32 => Structs.GlobalTransaction) globalTransactions;

    constructor (
        address _sidemesh,
        address _registery,
        address _verifier,
        address _lockManager){
            sidemesh = ISidemesh(_sidemesh);
            registry = IRegister(_registery);
            verifier = IVerifier(_verifier);
            lockManager = ILockManagerGlobalTransaction(_lockManager);
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

    function getDataForCheckTimeout(
        string memory network,
        uint chain,
        address sender)
        external view returns(bool, uint, uint){
            bytes32 xidKey = Utils.hash(abi.encodePacked(Constants.PREFIX, network, chain, sender));
            
            require(globalTransactionStatuses[xidKey].isValid, Constants.ERROR_NO_PRIMARY_TX);
            
            return(
                globalTransactionStatuses[xidKey].isValid,
                uint(globalTransactionStatuses[xidKey].status),
                globalTransactions[xidKey].ttlTime
                );
        }

    function startGlobalTransaction(
        uint ttlHeight,
        uint ttlTime)
        external{
            require(ttlHeight >= 0, Constants.ERROR_TTLHEIGHT);
            require(ttlTime != 0, Constants.ERROR_TTLTIME);
            string memory network = sidemesh.getNetwork();
            bytes32 xid = Utils.hash(abi.encodePacked(Constants.PREFIX, network, block.chainid, msg.sender));

            Structs.GlobalTransaction storage globalTx = globalTransactions[xid];
            globalTx.primaryPrepareTxId = Structs.TransactionID(Structs.URI(network, block.chainid), msg.sender);
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
            string memory primaryNetwork = sidemesh.getNetwork();
            bytes32 xid = Utils.hash(abi.encodePacked(Constants.PREFIX, primaryNetwork, block.chainid, msg.sender));

            Structs.NetworkTransaction memory txId;
            txId.txId = Structs.TransactionID(Structs.URI(network, chain), msg.sender);
            txId.invocation = Structs.Invocation(contractC, functionC, args);

            globalTransactions[xid].networkPrepareTxs[globalTransactions[xid].networkPrepareTxsLength] = txId;
            globalTransactions[xid].networkPrepareTxsLength++;
        }
    
    function preparePrimaryTransaction(
        string memory functionC) 
        external{
            string memory network = sidemesh.getNetwork();
            bytes32 xidKey = Utils.hash(abi.encodePacked(Constants.PREFIX, network, block.chainid, msg.sender));
            
            Structs.Invocation memory invocation;
            invocation.functionC = functionC;
            invocation.args = new string[](1);
            invocation.args[0] = Utils.toString(abi.encodePacked(msg.sender));
            
            Structs.NetworkTransaction memory txId;
            txId.txId = Structs.TransactionID(Structs.URI(network, block.chainid), msg.sender);
            txId.invocation = invocation;

            globalTransactions[xidKey].primaryConfirmTx = txId;

            Structs.GlobalTransactionStatus memory globalTxStatus;
            globalTxStatus.primaryPrepareTxId = globalTransactions[xidKey].primaryPrepareTxId;
            globalTxStatus.status = Enums.GlobalTransactionStatusType.PRIMARY_TRANSACTION_PREPARED;
            globalTxStatus.isValid = true;
            
            globalTransactionStatuses[xidKey] = globalTxStatus;

            if(lockManager.getWriteKeySetLength(xidKey) > 0){
                for(uint i=0; i<lockManager.getWriteKeySetLength(xidKey); i++){
                    lockManager.putWSet(xidKey, lockManager.getWriteKeySet(xidKey, i));
                }
            }

            Structs.Invocation memory queryGlobalTxInvocation;
            queryGlobalTxInvocation.functionC = Constants.QUERYGLOBALTXSTATUS;
            
            getNetworkTxs(xidKey, true);
            getNetworkTxs(xidKey, false);

            emit Structs.PrimaryTransactionPreparedEvent(
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
            string memory network = sidemesh.getNetwork();
            bytes32 xidKey = Utils.hash(abi.encodePacked(Constants.PREFIX, network, block.chainid, primaryPrepareTxSender));

            require(globalTransactionStatuses[xidKey].isValid, Constants.ERROR_NO_PRIMARY_TX);

            require(
                globalTransactionStatuses[xidKey].status == Enums.GlobalTransactionStatusType.PRIMARY_TRANSACTION_PREPARED,
                Constants.ERROR_DUPLICATE_TX_STATUS);

            require(globalTransactions[xidKey].isValid, Constants.ERROR_NO_GLOBAL_TX);

            require(
                globalTransactions[xidKey].networkPrepareTxsLength == networkTxRes.length,
                Constants.ERROR_DEPENDENT_TX
            );

            uint numVerified = 0;
            for(uint i=0;i<networkTxRes.length;i++){
                globalTransactions[xidKey].networkPrepareTxs[i].txId.sender = Utils.toAddress(networkTxRes[i][2]);
                globalTransactions[xidKey].networkPrepareTxs[i].proof = networkTxRes[i][3];

                (address contractC, string memory functionC) = verifier.resolve(networkTxRes[i][0], Utils.toUint(networkTxRes[i][1]));
                require(!Utils.checkAddress(contractC), Constants.ERROR_CONTRACT);
                require(!Utils.isEmpty(functionC), Constants.ERROR_FUNCTION);

                if(!Utils.isEmpty(networkTxRes[i][3])){
                    (bool success,) = contractC.call(abi.encodeWithSignature(functionC, networkTxRes[i][2], networkTxRes[i][3]));
                    require(success, Constants.ERROR_FAILED);
                    numVerified++;
                }
            }
            if (numVerified == globalTransactions[xidKey].networkPrepareTxsLength) {
                globalTransactionStatuses[xidKey].status = Enums.GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED;
            } else {
                globalTransactionStatuses[xidKey].status = Enums.GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED;
            }
            
            
            if(lockManager.getWSetLength(xidKey) > 0){
                for(uint i=0; i<lockManager.getWSetLength(xidKey); i++){
                    bytes32 hash = Utils.hash(abi.encodePacked(lockManager.getWSet(xidKey, i)));
                    
                    Structs.Lock memory lock = lockManager.getLock(hash);
                    
                    require(lock.isValid, Constants.ERROR_NO_LOCK);
                    
                    if(globalTransactionStatuses[xidKey].status == Enums.GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED){
                        lockManager.putLock(hash, lockManager.lockDeserializer(lock.updatingState));    
                    }else if(globalTransactionStatuses[xidKey].status == Enums.GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED){
                        lockManager.putLock(hash, lockManager.lockDeserializer(lock.prevState)); 
                    }
                }
            }
            
            for(uint i=0; i<globalTransactions[xidKey].networkPrepareTxsLength;i++){
                Structs.NetworkTransaction memory networkConfirmTx;
                Structs.TransactionID memory txId;
                txId.uri = Structs.URI(
                            globalTransactions[xidKey].networkPrepareTxs[i].txId.uri.network,
                            globalTransactions[xidKey].networkPrepareTxs[i].txId.uri.chain);
                networkConfirmTx.txId = txId;

                Structs.Invocation memory invocation;
                invocation.contractC = globalTransactions[xidKey].networkPrepareTxs[i].invocation.contractC;
                invocation.functionC = globalTransactions[xidKey].networkPrepareTxs[i].invocation.functionC;
                invocation.args = new string[](5);
                invocation.args[0] = Utils.toString(abi.encodePacked(globalTransactions[xidKey].networkPrepareTxs[i].txId.sender));
                invocation.args[1] = Utils.toString(abi.encodePacked(uint(globalTransactionStatuses[xidKey].status)));
                invocation.args[2] = network;
                invocation.args[3] = Utils.toString(abi.encodePacked(block.chainid));
                invocation.args[4] = Utils.toString(abi.encodePacked(msg.sender));

                networkConfirmTx.invocation = invocation;

                globalTransactions[xidKey].networkConfirmTxs[globalTransactions[xidKey].networkConfirmTxsLength] = networkConfirmTx;
                globalTransactions[xidKey].networkConfirmTxsLength++;
            }

            getNetworkTxs(xidKey, false);

            emit Structs.PrimaryTransactionConfirmedEvent(
                Structs.TransactionID(Structs.URI(network, block.chainid), msg.sender),
                networkConfirmTxs
            );
            delete networkConfirmTxs;
        }

    function startNetworkTransaction(
        string memory primaryNetwork,
        uint primaryChain,
        string memory primaryTxID,
        string memory primaryTxProof)
        external{
            require(!Utils.isEmpty(primaryTxProof), Constants.ERROR_PRIMARYTXPROOF);
            (address contractC, string memory functionC) = verifier.resolve(primaryNetwork, primaryChain);
            require(!Utils.checkAddress(contractC), Constants.ERROR_CONTRACT);
            require(!Utils.isEmpty(functionC), Constants.ERROR_FUNCTION);

            (bool success,) = contractC.call(abi.encodeWithSignature(functionC, primaryTxID, primaryTxProof));
            require(success, Constants.ERROR_FAILED);
        }
    
    function prepareNetworkTransaction(
        string memory primaryNetwork,
        uint primaryChain,
        address primaryTxSender,
        address globalTxQueryContract,
        string memory globalTxQueryFunc,
        string memory functionC)
        external{
            string memory network = sidemesh.getNetwork();
            
            Structs.TransactionID memory globalTxId = Structs.TransactionID(Structs.URI(primaryNetwork, primaryChain), primaryTxSender);
            Structs.Invocation memory globalTxQuery = Structs.Invocation(globalTxQueryContract, globalTxQueryFunc, new string[](1));
            globalTxQuery.args[0] = string(abi.encodePacked(primaryTxSender));

            bytes32 bidKey = Utils.hash(abi.encodePacked(Constants.PREFIX, network, block.chainid, msg.sender));
            if(lockManager.getWriteKeySetLength(bidKey) > 0){
                for(uint i=0; i<lockManager.getWriteKeySetLength(bidKey); i++){
                    lockManager.putWSet(bidKey, lockManager.getWriteKeySet(bidKey, i));
                }
            }
            
            Structs.Invocation memory invocation;
            invocation.functionC = functionC;
            invocation.args = new string[](1);
            invocation.args[0] = Utils.toString(abi.encodePacked(msg.sender));
            
            Structs.NetworkTransaction memory networkConfirmTx;
            networkConfirmTx.txId = Structs.TransactionID(Structs.URI(network, block.chainid), msg.sender);
            networkConfirmTx.invocation = invocation;

            emit Structs.NetworkTransactionPreparedEvent(
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
            require(!Utils.checkAddress(contractC), Constants.ERROR_CONTRACT);
            require(!Utils.isEmpty(functionC), Constants.ERROR_FUNCTION);

            require(!Utils.isEmpty(primaryConfirmTxProof), Constants.ERROR_NO_PRIMARY_CONFIRM_TX_PROOF);

            (bool success,) = contractC.call(abi.encodeWithSignature(functionC, primaryConfirmTxSender, primaryConfirmTxProof));
            require(success, Constants.ERROR_NO_PRIMARY_CONFIRM_TX);

            string memory network = sidemesh.getNetwork();
            bytes32 bidKey = Utils.hash(abi.encodePacked(Constants.PREFIX, network, block.chainid, networkPrepareTxSender));

            if(lockManager.getWSetLength(bidKey) > 0){
                for(uint i=0; i<lockManager.getWSetLength(bidKey); i++){
                    bytes32 hash = Utils.hash(abi.encodePacked(lockManager.getWSet(bidKey, i)));

                    Structs.Lock memory lock = lockManager.getLock(hash);

                    require(lock.isValid, Constants.ERROR_NO_LOCK);
                    
                    if(globalTxStatus == uint(Enums.GlobalTransactionStatusType.PRIMARY_TRANSACTION_COMMITTED)){
                        lockManager.putLock(hash, lockManager.lockDeserializer(lock.updatingState));    
                    }else if(globalTxStatus == uint(Enums.GlobalTransactionStatusType.PRIMARY_TRANSACTION_CANCELED)){
                        lockManager.putLock(hash, lockManager.lockDeserializer(lock.prevState)); 
                    }
                }
            }
    }
}