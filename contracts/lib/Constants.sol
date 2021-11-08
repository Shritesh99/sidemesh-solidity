// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

library Constants{
    string constant PREFIX = "SIDE_MESH_";

    string constant QUERYGLOBALTXSTATUS = "QueryGlobalTxStatus";

    string constant ERROR_REG_URI_NOT_FOUND = "[Register] Cant able find uri";
    string constant ERROR_VER_URI_NOT_FOUND = "[Verifier] Cant able find uri";
    string constant ERROR_NETWORK = "Network is empty";
    string constant ERROR_TTLTIME = "ttlTime at least one should be set";
    string constant ERROR_TTLHEIGHT = "ttlHeight at least one should be set";
    string constant ERROR_PRIMARYTXPROOF = "Need primary tx proof";
    string constant ERROR_CONTRACT = "Contract is empty";
    string constant ERROR_FUNCTION = "Function is empty";
    string constant ERROR_FAILED = "Primary tx verify failed";
    string constant ERROR_SECONDARY_LOCK = "This is a secondary lock";
    string constant ERROR_WRONG_CHAIN = "Wrong chain";
    string constant ERROR_NO_PRIMARY_TX = "Not found primary prepare tx status";
    string constant ERROR_NO_PRIMARY_CONFIRM_TX = "Primary confirm tx verify failed";
    string constant ERROR_NO_PRIMARY_CONFIRM_TX_PROOF = "Primary confirm tx proof cannot empty";
    string constant ERROR_NO_GLOBAL_TX = "Not found global tx";
    string constant ERROR_INVALID_TX_STATUS = "Invalid tx status it should not have lock";
    string constant ERROR_DUPLICATE_TX_STATUS = "Duplicate confirm global transaction request";
    string constant ERROR_INVALID_TIME = "Invalid Time";
    string constant ERROR_DEPENDENT_TX = "Dependent transaction result count not match branch prepare transaction count";
    string constant ERROR_EXPIRED_LOCK = "Need Release Expired Lock Error";
    string constant ERROR_NO_LOCK = "No Lock";
    
    string constant COLON = ":";
}