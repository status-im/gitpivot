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
import "GitHubUserReg.sol";
import "GitHubRepositoryReg.sol";
import "GitHubPoints.sol";

pragma solidity ^0.4.11;

contract GitHubOracle is Owned, DGitI {

    GitHubUserReg public userReg;
    GitHubRepositoryReg public repositoryReg;
    GitHubPoints public gitHubPoints;

    mapping (uint256 => Repository) repositories;
    mapping (uint256 => mapping (uint256 => uint256)) pendingPoints;

    struct Repository {
        bytes20 head;
        bytes20 tail;
    }
    
    function initialize() only_owner {
        userReg = QueryFactory.newUserReg();
        repositoryReg = QueryFactory.newRepositoryReg();
        gitHubPoints = QueryFactory.newPointsOracle();
    }

    function register(string _github_user, string _gistid) payable{
        userReg.register.value(msg.value)(msg.sender,_github_user,_gistid);
    }
    function updateCommits(string _repository) payable{
        gitHubPoints.updateCommits.value(msg.value)(_repository,db.getClaimedHead(_repository));
    }
    function addRepository(string _repository) payable{
        repositoryReg.addRepository.value(msg.value)(_repository);
    }
    function updateIssue(string _repository, string issue) payable{
        gitHubPoints.updateIssue.value(msg.value)(_repository,issue);
    }
    function getRepository(uint projectId) constant returns (address){
        return repositoryReg.getAddr(projectId);
    } 
    function getRepository(string full_name) constant returns (address){
        return repositoryReg.getAddr(full_name);
    } 

    modifier only_gitapi{
        if (msg.sender != address(gitHubApi)) throw;
        _;
    }
    
    event NewPoints(uint repoId, uint userId, uint total, bool claimed);

    function __newPoints(uint repoId, uint userId, uint total)
     only_gitapi {
		GitRepositoryI repoaddr = GitRepositoryI(repositoryReg.getAddr(repoId));
        bool claimed = repoaddr.claim(db.getUserAddress(userId), total);
		if(!claimed){ //try to claim points
		    addPending(repoId, userId, total); //set as a pending points
		}
        NewPoints(repository,userId,total,claimed); 
    }
    
    //claims pending points
    function claimPending(uint repoId, uint userId){
        GitRepositoryI repoaddr = GitRepositoryI(repositoryReg.getAddr(repoId));
        uint total = pending[_userId][_repoId];
        delete pending[_userId][_repoId];
        if(repoaddr.claim(gitHubUserRegistry.getAddr(userId), total)) {
            NewPoints(repository,userId,total,true);
        } else throw;
    }

    function addPending(uint256 _repoid, uint256 _userid, uint256 _points) internal {
        pending[_userId][_repoId] += _points;
    }
}