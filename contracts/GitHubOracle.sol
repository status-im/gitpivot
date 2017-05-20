/**
 * GitHubOracle.sol
 * Contract that oracle github API
 * GitHubOracle register users and create GitHubToken contracts
 * Registration requires user create a gist with only their account address
 * GitHubOracle will create one GitHubToken contract per repository
 * GitHubToken mint tokens by commit only for registered users in GitHubOracle
 * GitHubToken is a LockableCoin, that accept donatations and can be withdrawn by Token Holders
 * The lookups are done by Oraclize that charge a small fee
 * The contract itself will never charge any fee
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */
 
import "oraclizeAPI_0.4.sol";
import "Controlled.sol";
import "./GitHubUserReg.sol";
import "./GitHubRepositoryReg.sol";
import "./GitHubPoints.sol";

pragma solidity ^0.4.11;

contract GitHubOracle is Controlled, DGitI {

    GitHubUserReg public userReg;
    GitHubRepositoryReg public repositoryReg;
    GitHubPoints public gitHubPoints;

    mapping (uint256 => Repository) repositories;
    mapping (uint256 => mapping (uint256 => uint256)) pending;

    address public newContract;

    modifier oraclized {
        if(msg.sender != address(gitHubPoints)) throw;
        _;
    }
    modifier onlyUpgrading {
        if(newContract == 0) throw;
        _;
    }
    struct Repository {
        string head;
        string tail;
        mapping (string => string) pending;
    }

    function upgrade(uint[] _repoIds) onlyUpgrading {
        uint len = _repoIds.length;
		for(uint i = 0; i < len; i++){
            Controlled(repositoryReg.getAddr(_repoIds[i])).changeController(newContract);
        }
    }
    
    function start(string _repository, string _branch, string _token) payable {
        uint256 repoId = repositoryReg.getId(_repository);
        if(repoId == 0) throw;
        if(repositoryReg.getBranch(repoId) != sha3(_branch)) throw;
        gitHubPoints.start.value(msg.value)(_repository, _branch, _token);
    }
    
    function update(string _repository, string _branch, string _token) payable {
        uint256 repoId = repositoryReg.getId(_repository);
        if(repoId == 0) throw;
        if(repositoryReg.getBranch(repoId) != sha3(_branch)) throw;
        gitHubPoints.update.value(msg.value)(_repository, _branch, repositories[repoId].head, _token);
    }

    function resume(string _repository, string _branch, string _pendingTail, string _token) payable {
        uint256 repoId = repositoryReg.getId(_repository);
        if(repoId == 0) throw;
        if(repositoryReg.getBranch(repoId) != sha3(_branch)) throw;
        string claimedCommit = repositories[repoId].pending[_pendingTail];
        if(bytes(claimedCommit).length == 0) throw;
        delete repositories[repoId].pending[_pendingTail];
        gitHubPoints.resume.value(msg.value)(_repository, _branch, _pendingTail, claimedCommit, _token);
    }

    function longtail(string _repository, string _branch, string _token) payable {
        uint256 repoId = repositoryReg.getId(_repository);
        if(repoId == 0) throw;
        if(repositoryReg.getBranch(repoId) != sha3(_branch)) throw;
        gitHubPoints.longtail.value(msg.value)(_repository, _branch, repositories[repoId].tail, _token);
    }
    
    function issue(string _repository, string _issue, string _token) payable {
        gitHubPoints.issue.value(msg.value)(_repository,_issue,_token);
    }
    
    //claims pending points
    function claimPending(uint _repoId, uint _userId){
        GitRepositoryI repoaddr = GitRepositoryI(repositoryReg.getAddr(_repoId));
        uint total = pending[_userId][_repoId];
        delete pending[_userId][_repoId];
        if(!repoaddr.claim(userReg.getAddr(_userId), total)) throw;
    }
    
    function __init_regs() onlyController {
        if(address(userReg) == 0){
            userReg = GHUserReg.create();
        }
        if(address(repositoryReg) == 0){
            repositoryReg = GHRepoReg.create();
        }
    }

    function __set_points_script(string _arg) onlyController {
        if(address(gitHubPoints) == 0){
            gitHubPoints = GHPoints.create(_arg);
        } else {
            gitHubPoints.setScript(_arg);
        }
    }
    
    function __upgrade_contract(address _newContract) onlyController {
        userReg.changeController(_newContract);
        repositoryReg.changeController(_newContract);
        gitHubPoints.changeController(_newContract);
        newContract = _newContract;
        if(_newContract != 0) _newContract.send(this.balance);
    }

    function __pendingScan(uint256 _projectId, string _lastCommit, string _pendingTail) oraclized {
        repositories[_projectId].pending[_pendingTail] = _lastCommit;
    }
    
    function __setHead(uint256 _projectId, string _head) oraclized { 
        repositories[_projectId].head = _head;
    }
    
    function __setTail(uint256 _projectId, string _tail) oraclized {
        repositories[_projectId].tail = _tail;
    }
        
    function __setIssue(uint256 _projectId, uint256 _issueId, bool _state, uint256 _closedAt) oraclized {
        GitRepositoryI repo = GitRepositoryI(repositoryReg.getAddr(_projectId));
        repo.setBounty(_issueId, _state, _closedAt);
    }
         
    function __setIssuePoints(uint256 _projectId, uint256 _issueId, uint256[] _userId, uint256[] _points) oraclized {
        GitRepositoryI repo = GitRepositoryI(repositoryReg.getAddr(_projectId));
        uint len = _userId.length;
		for(uint i = 0; i < len; i++){
		    address addr = userReg.getAddr(_userId[i]);
		    repo.setBountyPoints(_issueId, addr, _points[i]);
		}
    }

    function __newPoints(uint _repoId, uint[] _userIds, uint[] _points) oraclized {
		GitRepositoryI repo = GitRepositoryI(repositoryReg.getAddr(_repoId));
		uint len = _userIds.length;
		for(uint i = 0; i < len; i++){
		    uint _userId = _userIds[i];
		    uint _uPoints = _points[i];
		    address addr = userReg.getAddr(_userId);
		    if(addr == 0x0 || !repo.claim(addr, _uPoints)){
		        pending[_userId][_repoId] += _uPoints;        
		    }
		}
    }
        
}