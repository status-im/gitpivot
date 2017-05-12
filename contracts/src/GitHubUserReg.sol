/** 
 * GitHubUserReg.sol 
 * Registers GitHub user login to an address
 * Ricardo Guilherme Schmidt <3esmit@gmail.com>
 */
import "GitHubAPIReg.sol";
import "NameRegistry.sol";

pragma solidity ^0.4.11;

contract GitHubUserReg is NameRegistry, GitHubAPIReg {

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
    
    function register(string _github_user, string _gistid) payable {
        bytes32 ocid = oraclize_query("nested", _getQuery(_github_user, _gistid));
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

    //internal helper functions
    function _getQuery(string _github_user, string _gistid) internal constant returns (string){
        string memory a = strConcat("[identity] ${[URL] https://gist.githubusercontent.com/", _github_user,"/",_gistid,"/raw/registereth.txt}, ${[URL] json(https://api.github.com/gists/"); 
        return strConcat(a, _gistid, credentials, ").owner.[login,id]}","");
    }

}