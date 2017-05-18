import "lib/oraclize/oraclizeAPI_0.4.sol";
import "lib/ethereans/management/Owned.sol";
import "lib/strings.sol";

pragma solidity ^0.4.11;

contract DGitI {
    function __setHead(uint256 projectId, string branch, bytes20 head);
    function __setTail(uint256 projectId, string branch, bytes20 tail);
    function __newPoints(uint256 projectId, uint256 userId, uint total);
    function __setIssue(uint256 projectId, uint256 issueId, bool state, uint256 closedAt);
    function __setIssuePoints(uint256 projectId, uint256 issueId, uint256 userId, uint256 points);
}

contract GitHubPoints is Owned, usingOraclize{

    string private cred = ""; 
    string private script = "";
    
    enum OracleType { CLAIM_COMMIT, CLAIM_CONTINUE, UPDATE_ISSUE }
    mapping (bytes32 => OracleType) claimType; //temporary db enumerating oraclize calls
    mapping (bytes32 => bytes20) commitClaim; //temporary db for oraclize commit token claim calls
    mapping (bytes32 => Request) request; //temporary db
    
    //stores temporary data for oraclize repository commit claim
    struct CommitClaim {
        string repository;
        bytes20 commitid;
    }
    
    struct Request {
        address caller;
        OracleType ot;
    }

    function _query_start(string _repository, string _branch, string _cred) internal {
        strConcat("[computation] ['", script, "', 'update-new', '", _repository, strConcat("','", _branch,"', '", _cred,"']"))
    }

    function start(string _repository, string _branch, string _cred) payable only_owner {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_start(_repository,_branch,_cred));
        claimType[ocid] = OracleType.CLAIM_COMMIT;
        request[ocid].caller = msg.sender;
        request[ocid].ot = OracleType.CLAIM_COMMIT;
    }
    
    function update(string _repository, string _branch, string _commitid, string _cred) payable only_owner {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_update(_repository,_branch,_commitid,_cred));
        claimType[ocid] = OracleType.CLAIM_COMMIT;
        commitClaim[ocid] = toBytes20(_commitid);
        request[ocid].caller = msg.sender;
        request[ocid].ot = OracleType.CLAIM_COMMIT;
    }
    
    function resume(string _repository, string _branch, string _lastCommit, string _limitCommit, string _cred)
     payable only_owner{
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_resume(_repository,_branch,_lastCommit,_limitCommit,_cred));
        claimType[ocid] = OracleType.CLAIM_CONTINUE;
        commitClaim[ocid] = toBytes20(_lastCommit);
        request[ocid].caller = msg.sender;
        request[ocid].ot = OracleType.CLAIM_CONTINUE;
    }
    
    function issue(string _repository, string issue, string _cred)
     payable only_owner{
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_issue(_repository,_issue,_cred));
        request[ocid].caller = msg.sender;
        request[ocid].ot = OracleType.UPDATE_ISSUE;
    }
    
    event OracleEvent(bytes32 myid, string result, bytes proof);
    //oraclize response callback
    function __callback(bytes32 myid, string result, bytes proof) {
        OracleEvent(myid, result, proof);
        if (msg.sender != oraclize.cbAddress()){
          throw;  
        }else if(claimType[myid] == OracleType.UPDATE_ISSUE){
            _updateIssue(myid, result);
        }else{
             _updateCommits(commitClaim[myid], result,claimType[myid]==OracleType.CLAIM_CONTINUE);
        }
        delete claimType[myid];  //should always be deleted
    }

    function _updateCommits(bytes20 oldCommit, string result, bool resume) internal {
        DGitI dGit = DGitI(owner);
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        (projectId,pos) = getNextUInt(v,pos);
        string memory branch;
        (branch,pos) = getNextString(v,pos);
        (temp,pos) = getNextString(v,pos);
        bytes20 head = toBytes20(temp);
        (temp,pos) = getNextString(v,pos);
        bytes20 tail = toBytes20(temp);
        dGit.__setHead(projectId,branch,head);
        if(resume){
            dGit.__setTail(projectId,branch,tail);    
        }else{
            if(oldCommit == 0x0){
                dGit.__setTail(projectId,branch,tail);    
            }else if (oldCommit != tail){
                //TODO: acceptContinueUpdateUntilLimit(tail,oldCommit)
            }
        }
        uint numAuthors;
        (numAuthors,pos) = getNextUInt(v,pos);
        uint userId;
        uint points;
        for(uint i; i < numAuthors; i++){
            (userId,pos) = getNextUInt(v,pos);
            (points,pos) = getNextUInt(v,pos);
            dGit.__newPoints(projectId,userId,points);
        }
    }
    
    function _updateIssue(bytes32 myid, string result) internal {
        DGitI dGit = DGitI(request[myid].caller);
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        (projectId,pos) = getNextUInt(v,pos);
        uint256 issueId; 
        (issueId,pos) = getNextUInt(v,pos);
        bool state;
        (temp,pos) = getNextString(v,pos);
        state = (sha3("open") == sha3(temp));
        uint256 closedAt; 
        (closedAt,pos) = getNextUInt(v,pos);
        uint numAuthors;
        (numAuthors,pos) = getNextUInt(v,pos);
        uint userId;
        uint points;
        dGit.__setIssue(projectId,issueId,state,closedAt);
        for(uint i; i < numAuthors; i++){
            (userId,pos) = getNextUInt(v,pos);
            (points,pos) = getNextUInt(v,pos);
            dGit.__setIssuePoints(projectId,issueId,userId,points);
        }
    }
    
    //owner management
    function GitHubPoints(string _script){
        script = _script;
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }
    
    function setAPICredentials(string _client_id_comma_client_secret) only_owner {
         cred = _client_id_comma_client_secret;
    }
    
    function setScript(string _script) only_owner{
        script = _script;
    }

    function clearAPICredentials() only_owner {
         cred = "";
     }

    function _query_script(string command, string args, string cred) internal returns (string)  {
       strings.slice memory comma = strings.toSlice("', '"); 
       strings.slice [] memory cm = new strings.slice[](4);
       cm[0] = script.toSlice();
       cm[1] = command.toSlice();
       cm[2] = args.toSlice();
       cm[3] = cred.toSlice();
       string memory array = comma.join(cm);
       cm = new strings.slice[](3);
       cm[0] = strings.toSlice("[computation] ['");
       cm[1] = array.toSlice();
       cm[2] = strings.toSlice("']");
       return strings.toSlice("").join(cm);        
    }
    
    function _query_start(string _repository, string _branch, string _cred)  internal returns (string)  {
       strings.slice memory comma = strings.toSlice(",");
       strings.slice [] memory cm = new strings.slice[](2);
       cm[0] = _repository.toSlice();
       cm[1] = _branch.toSlice();
       return _query_script("update",comma.join(cm),_cred);
    }

    function _query_update(string _repository, string _branch, string _lastCommit, string _cred)  internal returns (string)  {
       strings.slice memory comma = strings.toSlice(",");
       strings.slice [] memory cm = new strings.slice[](3);
       cm[0] = _repository.toSlice();
       cm[1] = _branch.toSlice();
       cm[2] = _lastCommit.toSlice();
       return _query_script("update",comma.join(cm),_cred);
    }
    
    function _query_resume(string _repository, string _branch, string _lastCommit, string _limitCommit, string _cred) internal constant returns (string){
       strings.slice memory comma = strings.toSlice(",");
       strings.slice [] memory cm = new strings.slice[](4);
       cm[0] = _repository.toSlice();
       cm[1] = _branch.toSlice();
       cm[2] = _lastCommit.toSlice();
       cm[3] = _limitCommit.toSlice();
       return _query_script("resume",comma.join(cm),_cred);
    }
    
    function _query_issue(string _repository, string _issue, string _cred) internal returns(string){
       strings.slice memory comma = strings.toSlice(",");
       strings.slice [] memory cm = new strings.slice[](2);
       cm[0] = _repository.toSlice();
       cm[1] = _issue.toSlice();
       return _query_script("resume",comma.join(cm),_cred);
    }
    
    //"ethereans/TheEtherian","master","client,secret"
    function query_start(string _repository, string _branch, string _cred)  constant returns (string)  {
        return _query_start(_repository,_branch,_cred);
    }
    
    //"ethereans/TheEtherian","master","3258ebfded07a6e35d400994db507e456e194716","client,secret"
    function query_update(string _repository, string _branch, string _lastCommit, string _cred)  constant returns (string)  {
        return _query_update(_repository,_branch,_lastCommit,_cred);
    }
    
    //"ethereans/TheEtherian","master","3258ebfded07a6e35d400994db507e456e194716","3acd26bf0f1f68ac2d7d26bfceb624bb0f01593a","client,secret"
    function query_resume(string _repository, string _branch, string _lastCommit, string _limitCommit, string _cred)  constant returns (string)  {
        return _query_resume(_repository,_branch,_lastCommit,_limitCommit,_cred);
    }
    
    //"ethereans/TheEtherian","1","client,secret"
    function query_issue(string _repository, string _issue, string _cred)  constant returns (string)  {
        return _query_issue(_repository,_issue,_cred);
    }

    function toBytes20(string memory source) internal constant returns (bytes20 result) {
        assembly {
            result := mload(add(source, 20))
        }
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

    function getNextString(bytes _str, uint8 _pos) internal constant returns (string, uint8) {
        uint8 start = 0;
        uint8 end = 0;
        uint strl =_str.length;
        for (;strl > _pos; _pos++) {
            if (_str[_pos] == '"'){ //Found quotation mark
                if(_str[_pos-1] != '\\'){ //is not escaped
	                end = start == 0 ? 0: _pos;
	                start = start == 0 ? (_pos+1) : start;
	                if(end > 0) break; 
                }
            }
        }
    	bytes memory str = new bytes(end-start);
        for(_pos=0; _pos<str.length; _pos++){
            str[_pos] = _str[start+_pos];
        }
        for(_pos=end+1; _pos<_str.length; _pos++) if (_str[_pos] == ','){ _pos++; break; } //end

        return (string(str),_pos);
	}

    function getNextUInt(bytes _str, uint8 _pos) internal constant returns (uint, uint8) {
        uint val = 0;
        uint strl =_str.length;
        for (; strl > _pos; _pos++) {
            byte bp = _str[_pos];
            if (bp == ','){ //Find ends
                _pos++; break;
            }else if ((bp >= 48)&&(bp <= 57)){ //only ASCII numbers
                val *= 10;
                val += uint(bp) - 48;
            }
        }
        return (val,_pos);
    }
}

library GitHubPointsFactory {

    function create() returns (GitHubPoints){
        return new GitHubPoints("");
    }

}