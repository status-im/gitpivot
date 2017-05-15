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
 
import "lib/oraclize/oraclizeAPI_0.4.sol";
import "lib/ethereans/management/Owned.sol";
import "./GitHubUserReg.sol";
import "./GitHubRepositoryReg.sol";
import "./GitHubPoints.sol";

pragma solidity ^0.4.11;

contract GitHubOracle is Owned, DGitI {

    GitHubUserReg public userReg;
    GitHubRepositoryReg public repositoryReg;
    GitHubPoints public gitHubPoints;

    mapping (uint256 => Repository) repositories;
    mapping (uint256 => mapping (uint256 => uint256)) pending;

    struct Repository {
        bytes20 head;
        bytes20 tail;
    }
    
    function initialize() only_owner {
        userReg = GitHubUserRegFactory.create();
        repositoryReg = GitHubRepositoryRegFactory.create();
        gitHubPoints = GitHubPointsFactory.create();
    }

    function updateCommits(string _repository, string _token) payable{
        uint256 repoId = repositoryReg.getId(_repository);
        if(repoId == 0) throw;
        gitHubPoints.updateCommits.value(msg.value)(_repository, "master", repositories[repoId].head,_token);
    }
    
    function updateIssue(string _repository, string issue, string _token) payable{
        gitHubPoints.updateIssue.value(msg.value)(_repository,issue,_token);
    }
    function getRepository(uint projectId) constant returns (address){
        return repositoryReg.getAddr(projectId);
    } 
    function getRepository(string full_name) constant returns (address){
        return repositoryReg.getAddr(full_name);
    } 

    event NewPoints(uint repoId, uint userId, uint total, bool claimed);

    function __newPoints(uint repoId, uint userId, uint total)
     only_owner {
		GitRepositoryI repoaddr = GitRepositoryI(repositoryReg.getAddr(repoId));
        bool claimed = repoaddr.claim(userReg.getAddr(userId), total);
		if(!claimed){ //try to claim points
		    addPending(repoId, userId, total); //set as a pending points
		}
        NewPoints(repoId,userId,total,claimed); 
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

    function addPending(uint256 _repoId, uint256 _userId, uint256 _points) internal {
        pending[_userId][_repoId] += _points;
    }
    
    
    
}