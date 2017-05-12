pragma solidity ^0.4.9;

import "lib/oraclize/oraclizeAPI_0.4.sol";
import "lib/StringLib.sol";
import "lib/JSONLib.sol";
import "lib/ethereans/management/Owned.sol";

contract DGitI {
    function __setHead(uint256 projectId, string branch, bytes20 head);
    function __setTail(uint256 projectId, string branch, bytes20 tail);
    function __newPoints(uint256 projectId, uint256 userId, uint total);
    function __setIssue(uint256 projectId, uint256 issueId, bool state, uint256 closedAt);
    function __setIssuePoints(uint256 projectId, uint256 issueId, uint256 userId, uint256 points);
}

contract GitHubPoints is Owned, usingOraclize{
    using StringLib for string;
    DGitI dGit
    
    string private cred = ""; 
    string private script = "";
    
    enum OracleType { CLAIM_COMMIT, CLAIM_CONTINUE, UPDATE_ISSUE }
    mapping (bytes32 => OracleType) claimType; //temporary db enumerating oraclize calls
    mapping (bytes32 => CommitClaim) commitClaim; //temporary db for oraclize commit token claim calls
    
    //stores temporary data for oraclize repository commit claim
    struct CommitClaim {
        string repository;
        bytes20 commitid;
    }
    
    function GitHubPoints(string _script){
        script = _script;
        dGit = DGitI(msg.sender);
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }
    
    function updateCommits(string _repository, string _branch, bytes20 _commitid)
     payable only_owner{
        bytes32 ocid = oraclize_query("computation", [script, "update-new",_repository.concat(",", _branch,",",toString(_commitid)),cred]);
        claimType[ocid] = OracleType.CLAIM_COMMIT;
        commitClaim[ocid] = CommitClaim( { repository: _repository, commitid:_commitid});
    }
    
    function continueUpdateCommits(string _repository, string _branch, bytes20 _lastCommit,bytes20 _limitCommit)
     payable only_owner{
        bytes32 ocid = oraclize_query("computation", [script, "update-old",_repository.concat(",", _branch,",",toString(_lastCommit)).concat(",",toString(_limitCommit)),cred]);
        claimType[ocid] = OracleType.CLAIM_CONTINUE;
    }
    
    function updateIssue(string _repository, string issue) payable only_owner{
         bytes32 ocid = oraclize_query("computation", [script, "issue-update",_repository.concat(",",issue),cred]);
    }
    
    event OracleEvent(bytes32 myid, string result, bytes proof);
    //oraclize response callback
    function __callback(bytes32 myid, string result, bytes proof) {
        OracleEvent(myid, result, proof);
        if (msg.sender != oraclize.cbAddress()){
          throw;  
        }else if(claimType[myid]==OracleType.CLAIM_COMMIT){ 
            _updateCommits(myid, result, false);
        }else if(claimType[myid]==OracleType.CLAIM_CONTINUE){ 
            _updateCommits(myid, result, true);
        }else if(claimType[myid] == OracleType.UPDATE_ISSUE){
            _updateIssue(myid, result);
        }
        delete claimType[myid];  //should always be deleted
    }

    function _updateCommits(bytes32 myid, string result, bool continuing) internal {
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        (projectId,pos) = JSONLib.getNextUInt(v,pos);
        string memory branch;
        (branch,pos) = JSONLib.getNextString(v,pos);
        (temp,pos) = JSONLib.getNextString(v,pos);
        bytes20 head = temp.toBytes20();
        (temp,pos) = JSONLib.getNextString(v,pos);
        bytes20 tail = temp.toBytes20();
        uint numAuthors;
        (numAuthors,pos) = JSONLib.getNextUInt(v,pos);
        uint userId;
        uint points;
        dGit.__setHead(projectId,branch,head);
        if(continuing){
            dGit.__setTail(projectId,branch,tail);    
        }else{
            bytes20 oldCommit = commitUpdate[myid].commitid;
            if(oldCommit == 0x0){
                dGit.__setTail(projectId,branch,tail);    
            }else if (oldCommit != tail){
                //TODO: acceptContinueUpdateUntilLimit(tail,oldCommit)
            }
        }
        for(uint i; i < numAuthors; i++){
            (userId,pos) = JSONLib.getNextUInt(v,pos);
            (points,pos) = JSONLib.getNextUInt(v,pos);
            dGit.__newPoints(projectId,userId,points);
        }
    }
    
    function _updateIssue(bytes32 myid, string result) internal {
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        (projectId,pos) = JSONLib.getNextUInt(v,pos);
        uint256 issueId; 
        (issueId,pos) = JSONLib.getNextUInt(v,pos);
        bool state;
        (temp,pos) = JSONLib.getNextString(v,pos);
        state = (temp.compare("open") == 0);
        uint256 closedAt; 
        (closedAt,pos) = JSONLib.getNextUInt(v,pos);
        uint numAuthors;
        (numAuthors,pos) = JSONLib.getNextUInt(v,pos);
        uint userId;
        uint points;
        dGit.__setIssue(projectId,issueId,state,closedAt);
        for(uint i; i < numAuthors; i++){
            (userId,pos) = JSONLib.getNextUInt(v,pos);
            (points,pos) = JSONLib.getNextUInt(v,pos);
            dGit.__setIssuePoints(projectId,issueId,userId,points);
        }
    }
    
    //owner management
    function setAPICredentials(string _client_id, string _client_secret) only_owner {
         cred = StringLib.concat(_client_id,",", _client_secret);
    }
    
    function setScript(string _script) only_owner{
        script = _script;
    }

    function clearAPICredentials() only_owner {
         cred = "";
     }

    function toString(bytes20 self) internal constant returns (string) {
        bytes memory bytesString = new bytes(20);
        uint charCount = 0;
        for (uint j = 0; j < 20; j++) {
            byte char = byte(bytes20(uint(self) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

}

library QueryFactory {

    function newGitHubAPI() returns (GitHubAPI){
        return new GitHubOracle();
    }

}