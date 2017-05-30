import "./oraclize/oraclizeAPI_0.4.sol";
import "./management/Controlled.sol";
import "./helpers/strings.sol";

pragma solidity ^0.4.11;

contract DGitI {
    function __setHead(uint256 projectId, string head);
    function __setTail(uint256 projectId, string tail);
    function __pendingScan(uint256 projectId, string lastCommit, string pendingTail);
    function __setIssue(uint256 projectId, uint256 issueId, bool state, uint256 closedAt);
    function __newPoints(uint256 projectId, uint256[] userIds, uint[] totals);
    function __setIssuePoints(uint256 projectId, uint256 issueId, uint256[] userIds, uint256[] points);
}

contract GitHubPoints is Controlled, usingOraclize{
    
    using strings for string;
    using strings for strings.slice;
    
    string private cred = ""; 
    string private script = "";
    
    enum Command { ISSUE, START, UPDATE, RESUME, RTAIL }
    mapping (bytes32 => Claim) claim; // temporary db 
    struct Claim {
        Command command;
        string lastCommit;
        string branch;
    }
    
    function start(string _repository, string _branch, string _cred) payable onlyController {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_start(_repository,_branch,_cred));
        claim[ocid] = Claim({command: Command.START, branch: _branch, lastCommit: ""});
    }
    
    function update(string _repository, string _branch, string _lastCommit, string _cred) payable onlyController {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_update(_repository,_branch,_lastCommit,_cred));
        claim[ocid] = Claim({command: Command.UPDATE, branch: _branch, lastCommit: _lastCommit});
    }
    
    function rtail(string _repository, string _branch, string _claimedTail, string _cred)
     payable onlyController {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_rtail(_repository,_branch,_claimedTail,_cred));
        claim[ocid] = Claim({command: Command.RTAIL, branch: _branch, lastCommit: ""});
    }
    
    function resume(string _repository, string _branch, string _pendingTail, string _claimedCommit, string _cred)
     payable onlyController {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_resume(_repository,_branch,_pendingTail,_claimedCommit,_cred));
        claim[ocid] = Claim({command: Command.RESUME, branch: _branch, lastCommit: _claimedCommit});
    }
    
    function issue(string _repository, string _issue, string _cred)
     payable onlyController {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_issue(_repository,_issue,_cred));
        claim[ocid].command = Command.ISSUE;
    }
    
    event OracleEvent(bytes32 myid, string result, bytes proof);
    //oraclize response callback
    function __callback(bytes32 myid, string result, bytes proof) {
        OracleEvent(myid, result, proof);
        if (msg.sender != oraclize.cbAddress()) throw; 
        _process(bytes(result),claim[myid]);
        delete claim[myid];
    }

    function _process(bytes v, Claim claim) internal {
        DGitI dGit = DGitI(controller);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId; 
        uint256 issueId; 
        (projectId,pos) = getNextUInt(v,pos);
        
        if(claim.command == Command.ISSUE){
            (issueId,pos) = getNextUInt(v,pos);
            (temp,pos) = getNextString(v,pos);//temp = issue state
            uint256 closedAt; 
            (closedAt,pos) = getNextUInt(v,pos);
            dGit.__setIssue(projectId,issueId,(sha3("open") == sha3(temp)),closedAt);
        } else {
            (temp,pos) = getNextString(v,pos); //temp = branch
            if(sha3(claim.branch) != sha3(temp)) return;    
            
            if(claim.command == Command.START || claim.command == Command.UPDATE){
                (temp,pos) = getNextString(v,pos); //temp = scan head
                dGit.__setHead(projectId,temp); 
            }
            (temp,pos) = getNextString(v,pos); //temp = scan tail
            if(claim.command == Command.START || claim.command == Command.RTAIL){
                dGit.__setTail(projectId,temp);   
            }
            if((claim.command == Command.RESUME || claim.command == Command.UPDATE) && sha3(claim.lastCommit) != sha3(temp)){
             //update didn't reached _lastCommit
                dGit.__pendingScan(projectId,temp,claim.lastCommit);
            }
        }
        uint numAuthors;
        (numAuthors,pos) = getNextUInt(v,pos);
        uint[] memory userId = new uint[](numAuthors);
        uint[] memory points = new uint[](numAuthors);
        for(uint i; i < numAuthors; i++){
            (userId[i],pos) = getNextUInt(v,pos);
            (points[i],pos) = getNextUInt(v,pos);
        }
        if(claim.command == Command.ISSUE){
            dGit.__setIssuePoints(projectId,issueId,userId,points);
        }else{
            dGit.__newPoints(projectId,userId,points); 
        }
    }
    
    //owner management
    function GitHubPoints(string _script){
        script = _script;
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
    
    function _query_resume(string _repository, string _branch, string _tail, string _claimedCommit, string _cred) internal constant returns (string){
       strings.slice memory comma = strings.toSlice(",");
       strings.slice [] memory cm = new strings.slice[](4);
       cm[0] = _repository.toSlice();
       cm[1] = _branch.toSlice();
       cm[2] = _tail.toSlice();
       cm[3] = _claimedCommit.toSlice();
       return _query_script("resume",comma.join(cm),_cred);
    }
    
    function _query_rtail(string _repository, string _branch, string _claimedTail, string _cred) internal constant returns (string){
       strings.slice memory comma = strings.toSlice(",");
       strings.slice [] memory cm = new strings.slice[](3);
       cm[0] = _repository.toSlice();
       cm[1] = _branch.toSlice();
       cm[2] = _claimedTail.toSlice();
       return _query_script("rtail",comma.join(cm),_cred);
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
