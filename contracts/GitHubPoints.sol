import "oraclizeAPI_0.4.sol";
import "Controlled.sol";
import "strings.sol";

pragma solidity ^0.4.11;

contract DGitI {
    function __setHead(uint256 projectId, string head);
    function __setTail(uint256 projectId, string tail);
    function __newPoints(uint256 projectId, uint256 userId, uint total);
    function __pendingScan(uint256 projectId, string lastCommit, string pendingTail);
    function __setIssue(uint256 projectId, uint256 issueId, bool state, uint256 closedAt);
    function __setIssuePoints(uint256 projectId, uint256 issueId, uint256 userId, uint256 points);
}

contract GitHubPoints is Controlled, usingOraclize{
    
    using strings for string;
    using strings for strings.slice;
    
    string private cred = ""; 
    string private script = "";
    
    enum Command { START, UPDATE, RESUME, ISSUE }
    mapping (bytes32 => Command) command; //temporary db enumerating oraclize calls
    mapping (bytes32 => string) lastCommits; //temporary db for oraclize commit token claim calls
    mapping (bytes32 => string) branches; 
    //stores temporary data for oraclize repository commit claim
    struct CommitClaim {
        string repository;
        bytes20 commitid;
    }
    
    function start(string _repository, string _branch, string _cred) payable onlyController {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_start(_repository,_branch,_cred));
        command[ocid] = Command.START;
        branches[ocid] = _branch;
    }
    
    function update(string _repository, string _branch, string _lastCommit, string _cred) payable onlyController {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_update(_repository,_branch,_lastCommit,_cred));
        command[ocid] = Command.UPDATE;
        lastCommits[ocid] = _lastCommit;
        branches[ocid] = _branch;
    }
    
    function resume(string _repository, string _branch, string _lastCommit, string _limitCommit, string _cred)
     payable onlyController {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_resume(_repository,_branch,_lastCommit,_limitCommit,_cred));
        command[ocid] = Command.RESUME;
        lastCommits[ocid] = _lastCommit;
        branches[ocid] = _branch;
    }
    
    function issue(string _repository, string _issue, string _cred)
     payable onlyController {
        if(bytes(_cred).length == 0) _cred = cred; 
        command[ocid] = Command.ISSUE;
        bytes32 ocid = oraclize_query("nested", _query_issue(_repository,_issue,_cred));
    }
    
    event OracleEvent(bytes32 myid, string result, bytes proof);
    //oraclize response callback
    function __callback(bytes32 myid, string result, bytes proof) {
        OracleEvent(myid, result, proof);
        if (msg.sender != oraclize.cbAddress()) throw; 
        Command comm = command[myid];
        if(comm == Command.UPDATE) {
            _update(branches[myid],lastCommits[myid], result);
            delete branches[myid];
        }else if(comm == Command.ISSUE) {
            _issue(result);
        }else if (comm == Command.RESUME) {
             _resume(branches[myid],lastCommits[myid], result);
             delete lastCommits[myid];
             delete branches[myid];
        }else if (comm == Command.START) {
             _start(branches[myid],result);
             delete branches[myid];
        }
        delete command[myid];
    }

    function _start(string _branch, string result) internal {
        DGitI dGit = DGitI(owner);
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        (projectId,pos) = getNextUInt(v,pos);
        (temp,pos) = getNextString(v,pos); //branch
        if(sha3(_branch) != sha3(temp)) return;
        (temp,pos) = getNextString(v,pos); //head
        dGit.__setHead(projectId,temp); //head
        (temp,pos) = getNextString(v,pos); //tail
        
        dGit.__setTail(projectId,temp);    
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

    function _update(string _branch, string _lastCommit, string result) internal {
        DGitI dGit = DGitI(owner);
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        (projectId,pos) = getNextUInt(v,pos);
        (temp,pos) = getNextString(v,pos); //branch
        if(sha3(_branch) != sha3(temp)) return;
        (temp,pos) = getNextString(v,pos); //head
        dGit.__setHead(projectId,temp); //head
        
        (temp,pos) = getNextString(v,pos); //tail
        if(bytes(_lastCommit).length == 0){
            dGit.__setTail(projectId,temp);    
        }
        if (sha3(_lastCommit) != sha3(temp)){ //update didn't reached _lastCommit
            dGit.__pendingScan(projectId,_lastCommit,temp);
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

    function _resume(string _branch, string _lastCommit, string result) internal {
        DGitI dGit = DGitI(owner);
        bytes memory v = bytes(result);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        (projectId,pos) = getNextUInt(v,pos);
        string memory branch;
        (branch,pos) = getNextString(v,pos);
        if(sha3(_branch) != sha3(branch)) return;
        string memory head;
        (head,pos) = getNextString(v,pos);
        string memory tail;
        (tail,pos) = getNextString(v,pos);
        dGit.__setTail(projectId,tail);    
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
    
    function _issue(string result) internal {
        DGitI dGit = DGitI(owner);
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
    
    function setAPICredentials(string _client_id_comma_client_secret) onlyController {
         cred = _client_id_comma_client_secret;
    }
    
    function setScript(string _script) onlyController{
        script = _script;
    }

    function clearAPICredentials() onlyController {
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
       return _query_script("start",comma.join(cm),_cred);
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
       return _query_script("issue",comma.join(cm),_cred);
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

library GHPoints {

    function create(string _script) returns (GitHubPoints){
        return new GitHubPoints(_script);
    }

}
