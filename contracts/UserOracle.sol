pragma solidity ^0.4.11;

import "./GitHubAPIReg.sol";
import "./common/strings.sol";
import "./management/RegistryIndex.sol";

/** 
 * @title GitHubUserReg.sol 
 * Registers GitHub user login to an address
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)]
 */
contract UserOracle is GitHubAPIReg, RegistryIndex {
    using strings for string;
    using strings for strings.slice;
    
    mapping (bytes32 => UserClaim) userClaim; //temporary db for oraclize user register queries


    event RegisterUpdated(string name);
 
    //stores temporary data for oraclize user register request
    struct UserClaim {
        address sender;
        string login;
    }

    
    function register(string _githubUser, string _gistId, string _cred) public payable {
        if (bytes(_cred).length == 0) {
            _cred = cred; 
        }
        bytes32 ocid = oraclize_query("nested", _queryScript(_githubUser, _gistId, _cred));
        userClaim[ocid] = UserClaim({sender: msg.sender, login: _githubUser});
    }


    //oraclize response callback
    function __callback(bytes32 myid, string result, bytes proof) public {
        OracleEvent(myid, result, proof);
        require(msg.sender == oraclize.cbAddress());
        _register(myid, result);
    }

    function _register(bytes32 myid, string result) internal {
        bytes memory v = bytes(result);
        uint8 pos = 0;
        address addrLoaded; 
        string memory login; 
        uint256 userId; 
        (addrLoaded, pos) = getNextAddr(v, pos);
        (login, pos) = getNextString(v, pos);
        (userId, pos) = getNextUInt(v, pos);
        if (userClaim[myid].sender == addrLoaded && keccak256(userClaim[myid].login) == keccak256(login)) {
            RegisterUpdated(login);
            setRegistry(userId, addrLoaded, login);
        }
        delete userClaim[myid];
    }

    function _queryScript(string _githubUser, string _gistId, string _cred) internal returns (string) {
        strings.slice[] memory cm = new strings.slice[](8);
        cm[0] = strings.toSlice("[identity] ${[URL] https://gist.githubusercontent.com/");
        cm[1] = _githubUser.toSlice();
        cm[2] = strings.toSlice("/");
        cm[3] = _gistId.toSlice();
        cm[4] = strings.toSlice("/raw/register.txt}, ${[URL] json(https://api.github.com/gists/");
        cm[5] = _gistId.toSlice();
        cm[6] = _cred.toSlice();
        cm[7] = strings.toSlice(").owner.[login,id]}");
        return strings.toSlice("").join(cm);
    }

}
