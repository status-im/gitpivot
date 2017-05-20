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
    
    modifier oraclized {
        if(msg.sender != address(gitHubPoints)) throw;
        _;
    }
    
    struct Repository {
        string head;
        string tail;
        mapping (string => string) pending;
    }
    
    function __init_regs() onlyController {
        if(address(userReg) == 0x0){
            userReg = GHUserReg.create();
        }
        if(address(repositoryReg) == 0x0){
            repositoryReg = GHRepoReg.create();
        }
    }

    function __set_points_script(string _arg) onlyController {
        if(address(gitHubPoints) == 0x0){
            gitHubPoints = GHPoints.create(_arg);
        }else {
            gitHubPoints.setScript(_arg);
        }
    }
    
    function __changeController(address _newController) onlyController {
        userReg.changeController(_newController);
        repoReg.changeController(newContract);
        gitHubPoints.changeController(newContract);
    }

    function update(string _repository, string _token) payable {
        uint256 repoId = repositoryReg.getId(_repository);
        if(repoId == 0) throw;
        gitHubPoints.update.value(msg.value)(_repository, "master", repositories[repoId].head,_token);
    }
    
    function issue(string _repository, string _issue, string _token) payable {
        gitHubPoints.issue.value(msg.value)(_repository,_issue,_token);
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
         
    function __setIssuePoints(uint256 _projectId, uint256 _issueId, uint256 _userId, uint256 _points) oraclized {
        GitRepositoryI repo = GitRepositoryI(repositoryReg.getAddr(_projectId));
        repo.setBountyPoints(_issueId, userReg.getAddr(_userId), _points);
    }

    event NewPoints(uint repoId, uint userId, uint total, bool claimed);

    function __newPoints(uint _repoId, uint _userId, uint _points)
     oraclized {
		GitRepositoryI repoaddr = GitRepositoryI(repositoryReg.getAddr(_repoId));
        bool claimed = repoaddr.claim(userReg.getAddr(_userId), _points);
		if(!claimed){ //try to claim points
		    pending[_userId][_repoId] += _points; //set as a pending points
		}
        NewPoints(_repoId, _userId, _points, claimed); 
    }
    
    //claims pending points
    function claimPending(uint _repoId, uint _userId){
        GitRepositoryI repoaddr = GitRepositoryI(repositoryReg.getAddr(_repoId));
        uint total = pending[_userId][_repoId];
        delete pending[_userId][_repoId];
        if(repoaddr.claim(userReg.getAddr(_userId), total)) {
            NewPoints(_repoId,_userId,total,true);
        } else throw;
    }
        
}