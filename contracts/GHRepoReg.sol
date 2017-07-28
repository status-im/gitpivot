pragma solidity ^0.4.11;

import "./GitHubAPIReg.sol";
import "./management/NameRegistry.sol";
import "./GitRepository.sol";
import "./helpers/strings.sol";

/** 
 * @title GitHubRepositoryReg.sol
 * Registers the master branch of a Repository for GitHubOracle tracking.
 * @author Ricardo Guilherme Schmidt
 */
contract GitHubRepositoryReg is NameRegistry, GitHubAPIReg {
    using strings for string;
    using strings for strings.slice;
    
    mapping (uint256 => Repository) public repositories; 

    event NewRepository(address addr, uint256 projectId, string full_name, string default_branch);
    
    struct Repository {
        address addr; 
        string name;
        bytes32 branch; 
    }

    function register(string _repository, string _cred) payable {
        if(bytes(_cred).length == 0) _cred = cred; 
        uint gas = getAddr(_repository) == 0x00? 4000000 : 1000000;
        oraclize_query("URL", _query_script(_repository,_cred), gas);
    }

    function getAddr(uint256 _id) public constant returns(address addr) {
        return repositories[_id].addr;
    }

     function getName(address _addr) public constant returns(string name){
        return repositories[indexes[sha3(_addr)]].name;
    } 

    function getAddr(string _name) public constant returns(address addr) {
        return repositories[indexes[sha3(_name)]].addr;
    }
    
    function getBranch(uint256 _id) public constant returns(bytes32 branch) {
        return repositories[_id].branch;
    }

    //oraclize response callback
    function __callback(bytes32 myid, string result, bytes proof) {
        OracleEvent(myid,result,proof);
        if (msg.sender != oraclize.cbAddress()){
          throw;  
        }else {
            _setRepository(result);
        }
    }

    function _setRepository(string result) internal //[85743750, "ethereans/TheEtherian", "master"]
    {
        bytes memory v = bytes(result);
        uint8 pos = 0;
        uint256 projectId; 
        (projectId,pos) = getNextUInt(v,pos);
        string memory full_name;
        (full_name,pos) = getNextString(v,pos);
        string memory default_branch;
        (default_branch,pos) = getNextString(v,pos);
        address repoAddr = repositories[projectId].addr;
        if(repoAddr == 0x0){   
            GitRepositoryI repo = new GitRepository(projectId, full_name);
            repo.changeController(controller);
            repoAddr = address(repo);
            indexes[sha3(repoAddr)] = projectId; 
            indexes[sha3(full_name)] = projectId;
            NewRepository(repoAddr, projectId, full_name, default_branch);
            repositories[projectId] = Repository({addr: repoAddr, name: full_name, branch: sha3(default_branch)});
        }else{
            bytes32 _new = sha3(full_name);
            bytes32 _old = sha3(repositories[projectId].name);
            if(_new != _old){
                _updateIndex(_old, _new);
            }
        }
    }
    //internal helper functions
    function _query_script(string _repository, string _cred) internal returns (string)  {
       strings.slice [] memory cm  = new strings.slice[](5);
       cm[0] = strings.toSlice("json(https://api.github.com/repos/");
       cm[1] = _repository.toSlice();
       cm[2] = _cred.toSlice();
       cm[4] = strings.toSlice(").$.id,full_name,default_branch");
       return strings.toSlice("").join(cm);        
    }
}
library GHRepoReg {

    function create() returns (GitHubRepositoryReg){
        return new GitHubRepositoryReg();
    }

}
