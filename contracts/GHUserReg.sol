pragma solidity ^0.4.11;
import "./GitHubAPIReg.sol";
import "./management/NameRegistry.sol";
import "./helpers/strings.sol";

/** 
 * @title GitHubUserReg.sol 
 * Registers GitHub user login to an address
 * @author Ricardo Guilherme Schmidt 
 */
contract GitHubUserReg is NameRegistry, GitHubAPIReg {
    using strings for string;
    using strings for strings.slice;
    
    mapping (bytes32 => UserClaim) userClaim; //temporary db for oraclize user register queries
    mapping (uint256 => User) users; 

    event RegisterUpdated(string name);
 
    //stores temporary data for oraclize user register request
    struct UserClaim {
        address sender;
        string login;
    }
    
    struct User {
        address addr; 
        string login; 
    }
    
    function register(string _github_user, string _gistid, string _cred) payable {
        if(bytes(_cred).length == 0) _cred = cred; 
        bytes32 ocid = oraclize_query("nested", _query_script(_github_user, _gistid,_cred));
        userClaim[ocid] = UserClaim({sender: msg.sender, login: _github_user});
    }

    function getAddr(uint256 _id) public constant returns(address addr) {
        return users[_id].addr;
    }

     function getName(address _addr) public constant returns(string name){
        return users[indexes[sha3(_addr)]].login;
    } 

    function getAddr(string _name) public constant returns(address addr) {
        return users[indexes[sha3(_name)]].addr;
    }

    //oraclize response callback
    function __callback(bytes32 myid, string result, bytes proof) {
        OracleEvent(myid, result, proof);
        if (msg.sender != oraclize.cbAddress()){
          throw;  
        }else {
            _register(myid, result);
        }
    }

    function _register(bytes32 myid, string result) internal {
        bytes memory v = bytes(result);
        uint8 pos = 0;
        address addrLoaded; 
        string memory login; 
        uint256 userId; 
        (addrLoaded,pos) = getNextAddr(v,pos);
        (login,pos) = getNextString(v,pos);
        (userId,pos) = getNextUInt(v,pos);
        if(userClaim[myid].sender == addrLoaded && sha3(userClaim[myid].login) == sha3(login)){
            RegisterUpdated(login);
            if(users[userId].addr != 0x0){
                delete indexes[sha3(users[userId].login)];
                delete indexes[sha3(users[userId].addr)];
            }
            indexes[sha3(addrLoaded)] = userId;
            indexes[sha3(login)] = userId;
            users[userId].addr = addrLoaded;
            users[userId].login = login;
        }
        delete userClaim[myid]; //should always be deleted
    }

    function _query_script(string _github_user, string _gistid, string _cred) internal returns (string)  {
       strings.slice [] memory cm = new strings.slice[](8);
       cm[0] = strings.toSlice("[identity] ${[URL] https://gist.githubusercontent.com/");
       cm[1] = _github_user.toSlice();
       cm[2] = strings.toSlice("/");
       cm[3] = _gistid.toSlice();
       cm[4] = strings.toSlice("/raw/register.txt}, ${[URL] json(https://api.github.com/gists/");
       cm[5] = _gistid.toSlice();
       cm[6] = _cred.toSlice();
       cm[7] = strings.toSlice(").owner.[login,id]}");
       return strings.toSlice("").join(cm);        
    }

}

library GHUserReg{

    function create() returns (GitHubUserReg){
        return new GitHubUserReg();
    }

}