pragma solidity ^0.4.10;

import "./common/oraclizeAPI_0.4.sol";
import "./common/Controlled.sol";
import "./common/strings.sol";

/**
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH) 
 */
contract GitPivotI {

    /**
     * 
     */
    function setHead(uint256 projectId, string head) public;

    /**
     * 
     */
    function setTail(uint256 projectId, string tail) public;

    /**
     * 
     */
    function newPoints(uint256 projectId, uint256[] userIds, uint[] totals) public;

    /**
     * 
     */
    function pendingScan(uint256 projectId, string lastCommit, string pendingTail) public;

    /**
     * 
     */
    function setIssue(
        uint256 projectId,
        uint256 issueId,
        bool state,
        uint256 closedAt) public;

    /**
     * 
     */
    function setIssuePoints(
        uint256 projectId, 
        uint256 issueId,
        uint256[] userIds, 
        uint256[] points) public;

}


/**
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH) 
 */
contract PointsOracle is Controlled, usingOraclize {
    
    event OracleEvent(bytes32 myid, string result, bytes proof);
    using strings for string;
    using strings for strings.slice;
    
    string private cred = ""; 
    string private script = "";
    
    enum Command { ISSUE, START, UPDATE, RESUME, RTAIL }
    mapping (bytes32 => Request) request; // temporary db 

    struct Request {
        Command command;
        string lastCommit;
        string branch;
    }
    

    /**
     * 
     */
    modifier credentials(string _cred) {
        if (bytes(_cred).length == 0) {
            _cred = cred;
        }
        _;
    }

    /**
     * 
     */
    function start(string _repository, string _branch, string _cred)
        public 
        payable
        credentials(_cred) 
        onlyController 
        returns(bytes32 ocid) 
    {
        ocid = oraclize_query("nested", queryStart(_repository,_branch,_cred));
        request[ocid] = Request({
            command: Command.START,
            branch: _branch,
            lastCommit: ""
        });
    }

    /**
     * 
     */
    function update(
        string _repository, 
        string _branch, 
        string _lastCommit, 
        string _cred
    )
        public 
        payable
        credentials(_cred) 
        onlyController 
        returns(bytes32 ocid) 
    {
        ocid = oraclize_query(
            "nested",
            queryUpdate(
                _repository,
                _branch,
                _lastCommit,
                _cred
            )
        );
        request[ocid] = Request({
            command: Command.UPDATE,
            branch: _branch,
            lastCommit: _lastCommit
        });
    }

    /**
     * 
     */
    function rtail(
        string _repository, 
        string _branch, 
        string _requestedTail, 
        string _cred
    )
        public 
        payable
        credentials(_cred) 
        onlyController 
        returns(bytes32 ocid) 
    {
        ocid = oraclize_query(
            "nested", 
            queryRtail(
                _repository, 
                _branch, 
                _requestedTail, 
                _cred
            )
        );
        request[ocid] = Request({
            command: Command.RTAIL,
            branch: _branch,
            lastCommit: ""
        });
    }

    /**
     * 
     */
    function resume(
        string _repository,
        string _branch,
        string _pendingTail,
        string _requestedCommit,
        string _cred
    )
        public
        payable
        credentials(_cred) 
        onlyController 
        returns(bytes32 ocid) 
    {
        ocid = oraclize_query(
            "nested", 
            queryResume(
                _repository,
                _branch,
                _pendingTail,
                _requestedCommit,
                _cred
            )
        );
        request[ocid] = Request({
            command: Command.RESUME,
            branch: _branch,
            lastCommit: _requestedCommit
        });
    }

    /**
     * 
     */
    function issue(string _repository, string _issue, string _cred)
        public
        payable
        credentials(_cred)
        onlyController
        returns(bytes32 ocid)
    {
        ocid = oraclize_query(
            "nested", 
            queryIssue(
                _repository,
                _issue,
                _cred
            )
        );
        request[ocid].command = Command.ISSUE;
    }

    /**
     * 
     */
    function __callback(bytes32 myid, string result, bytes proof) public {
        OracleEvent(myid, result, proof);
        require (msg.sender == oraclize.cbAddress());
        processRequest(bytes(result), request[myid]);
        delete request[myid];
    }

    /**
     * 
     */
    function processRequest(bytes v, Request _request) 
        internal
    {
        GitPivotI pivot = GitPivotI(controller);
        uint8 pos = 0;
        string memory temp;
        uint256 projectId;
        uint256 issueId;
        (projectId, pos) = getNextUInt(v, pos);
        if (_request.command == Command.ISSUE) {
            (issueId, pos) = getNextUInt(v, pos);
            (temp, pos) = getNextString(v, pos);//temp = issue state
            uint256 closedAt; 
            (closedAt, pos) = getNextUInt(v, pos);
            bool open = (keccak256("open") == keccak256(temp));
            pivot.setIssue(
                projectId,
                issueId,
                open,
                closedAt
            );
        } else {
            (temp,pos) = getNextString(v, pos); //temp = branch
            if (keccak256(_request.branch) != keccak256(temp)) 
                return;
            
            if (_request.command == Command.START || _request.command == Command.UPDATE) {
                (temp, pos) = getNextString(v, pos); //temp = scan head
                pivot.setHead(projectId, temp); 
            }
            (temp,pos) = getNextString(v,pos); //temp = scan tail
            if (_request.command == Command.START || _request.command == Command.RTAIL) {
                pivot.setTail(projectId, temp);   
            }
            if ((_request.command == Command.RESUME || _request.command == Command.UPDATE) && keccak256(_request.lastCommit) != keccak256(temp)) {
             //update didn't reached _lastCommit
                pivot.pendingScan(projectId, temp, _request.lastCommit);
            }
        }
        uint numAuthors;
        (numAuthors,pos) = getNextUInt(v,pos);
        uint[] memory userId = new uint[](numAuthors);
        uint[] memory points = new uint[](numAuthors);
        for (uint i; i < numAuthors; i++) {
            (userId[i],pos) = getNextUInt(v,pos);
            (points[i],pos) = getNextUInt(v,pos);
        }
        if (_request.command == Command.ISSUE) {
            pivot.setIssuePoints(
                projectId,
                issueId,
                userId,
                points
            );
        } else {
            pivot.newPoints(projectId,userId,points);
        }
    }

    /**
     * 
     */
    function PointsOracle(string _script) {
        script = _script;
    }


    /**
     * 
     */  
    function setAPICredentials(string _clientIdCommaClinetSecret) public onlyController {
        cred = _clientIdCommaClinetSecret;
    }

    /**
     * 
     */
    function setScript(string _script) public onlyController {
        script = _script;
    }

    /**
     * 
     */
    function clearAPICredentials() public onlyController {
        cred = "";
    }

    /**
     * 
     */
    function queryScript(string _command, string _args, string _cred) 
        internal 
        returns (string) 
    {
        strings.slice memory comma = strings.toSlice("', '"); 
        strings.slice[] memory cm = new strings.slice[](4);
        cm[0] = script.toSlice();
        cm[1] = _command.toSlice();
        cm[2] = _args.toSlice();
        cm[3] = _cred.toSlice();
        string memory array = comma.join(cm);
        cm = new strings.slice[](3);
        cm[0] = strings.toSlice("[computation] ['");
        cm[1] = array.toSlice();
        cm[2] = strings.toSlice("']");
        return strings.toSlice("").join(cm);
    }

    /**
     * 
     */
    function queryStart(string _repository, string _branch, string _cred)
        internal
        returns (string)
    {
        strings.slice memory comma = strings.toSlice(",");
        strings.slice[] memory cm = new strings.slice[](2);
        cm[0] = _repository.toSlice();
        cm[1] = _branch.toSlice();
        return queryScript("start",comma.join(cm),_cred);
    }

    /**
     * 
     */
    function queryUpdate(
        string _repository,
        string _branch,
        string _lastCommit,
        string _cred
    )
        internal
        returns (string)
    {
        strings.slice memory comma = strings.toSlice(",");
        strings.slice[] memory cm = new strings.slice[](3);
        cm[0] = _repository.toSlice();
        cm[1] = _branch.toSlice();
        cm[2] = _lastCommit.toSlice();
        return queryScript("update",comma.join(cm),_cred);
    }

    /**
     * 
     */
    function queryResume(
        string _repository,
        string _branch,
        string _tail,
        string _requestedCommit,
        string _cred
    ) 
        internal
        returns (string)
    {
        strings.slice memory comma = strings.toSlice(",");
        strings.slice[] memory cm = new strings.slice[](4);
        cm[0] = _repository.toSlice();
        cm[1] = _branch.toSlice();
        cm[2] = _tail.toSlice();
        cm[3] = _requestedCommit.toSlice();
        return queryScript("resume",comma.join(cm),_cred);
    }

    /**
     * 
     */
    function queryRtail(
        string _repository,
        string _branch,
        string _requestedTail,
        string _cred
    )
        internal
        returns (string)
    {
        strings.slice memory comma = strings.toSlice(",");
        strings.slice[] memory cm = new strings.slice[](3);
        cm[0] = _repository.toSlice();
        cm[1] = _branch.toSlice();
        cm[2] = _requestedTail.toSlice();
        return queryScript("rtail",comma.join(cm),_cred);
    }

    /**
     * 
     */
    function queryIssue(string _repository, string _issue, string _cred)
        internal
        returns(string)
    {
        strings.slice memory comma = strings.toSlice(",");
        strings.slice[] memory cm = new strings.slice[](2);
        cm[0] = _repository.toSlice();
        cm[1] = _issue.toSlice();
        return queryScript("issue",comma.join(cm),_cred);
    }

    /**
     * 
     */
    function toBytes20(string memory source)
        internal
        constant
        returns (bytes20 result)
    {
        assembly {
            result := mload(add(source, 20))
        }
    }

    /**
     * 
     */
    function getNextString(bytes _str, uint8 _pos)
        internal
        constant
        returns (string, uint8) 
    {
        uint8 _start = 0;
        uint8 end = 0;
        uint strl = _str.length;
        for (;strl > _pos; _pos++) {
            if (_str[_pos] == "\"") { //Found quotation mark
                if (_str[_pos-1] != "\\") { //is not escaped
                    end = _start == 0 ? 0 : _pos;
                    _start = _start == 0 ? (_pos + 1) : _start;
                    if (end > 0)
                        break;
                }
            }
        }
        bytes memory str = new bytes(end - _start);
        for (_pos = 0; _pos < str.length; _pos++) {
            str[_pos] = _str[_start + _pos];
        }
        for (_pos = end + 1; _pos < _str.length; _pos++) { 
            if (_str[_pos] == ",") {
                _pos++; 
                break; 
            } //end
        }
        return (string(str), _pos);
    }

    /**
     * 
     */
    function getNextUInt(bytes _str, uint8 _continue)
        internal
        constant
        returns (uint val, uint8 _pos)
    {
        val = 0;
        uint strl = _str.length;
        for (_pos = _continue; strl > _pos; _pos++) {
            byte bp = _str[_pos];
            if (bp == ",") { //Find ends
                _pos++; 
                break;
            } else if ((bp >= 48)&&(bp <= 57)) { //only ASCII numbers
                val *= 10;
                val += uint(bp) - 48;
            }
        }
        return (val, _pos);
    }
}