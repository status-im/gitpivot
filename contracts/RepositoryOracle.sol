pragma solidity ^0.4.11;

import "./GitHubAPIReg.sol";
import "./management/RegistryIndex.sol";
import "./GitRepository.sol";
import "./common/strings.sol";


/** 
 * @title RepositoryOracle
 * Registers the master branch of a Repository for GitHubOracle tracking.
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)]
 */
contract RepositoryOracle is GitHubAPIReg, RegistryIndex {
    using strings for string;
    using strings for strings.slice;
    
    mapping (uint256 => bytes32) public branch; 

    event NewRepository(address addr, uint256 projectId, string fullName, string defaultBranch);
    
    function register(string _repository, string _cred) payable {
        if (bytes(_cred).length == 0) {
            _cred = cred; 
        }
        uint gas = getAddr(_repository) == 0x00? 4000000 : 1000000;
        oraclize_query(
            "URL",
            queryScript(_repository, _cred),
            gas
        );
    }
  
    //oraclize response callback
    function __callback(bytes32 myid, string result, bytes proof) {
        OracleEvent(myid, result, proof);
        require(msg.sender == oraclize.cbAddress());
        _setRepository(result);
    }

    function _setRepository(string result) 
        internal //[85743750, "ethereans/TheEtherian", "master"]
    {
        bytes memory v = bytes(result);
        uint8 pos = 0;
        uint256 projectId; 
        (projectId, pos) = getNextUInt(v, pos);
        string memory full_name;
        (full_name, pos) = getNextString(v, pos);
        string memory default_branch;
        (default_branch, pos) = getNextString(v, pos);
        address repoAddr = registry[projectId].addr;
        if (repoAddr == 0x0) {   
            NewRepository(repoAddr, projectId, full_name, default_branch);
            GitRepositoryI repo = new GitRepository(projectId, full_name);
            repo.changeController(controller);
            repoAddr = address(repo);            
            branch[projectId] = keccak256(default_branch);
            setRegistry(repoAddr, projectId, full_name);
        } else {
            updateIndex(repositories[projectId].name, full_name);
        }
    }
    //internal helper functions
    function queryScript(string _repository, string _cred) internal returns (string) {
       strings.slice[] memory cm  = new strings.slice[](5);
       cm[0] = strings.toSlice("json(https://api.github.com/repos/");
       cm[1] = _repository.toSlice();
       cm[2] = _cred.toSlice();
       cm[4] = strings.toSlice(").$.id,full_name,default_branch");
       return strings.toSlice("").join(cm);        
    }
}
