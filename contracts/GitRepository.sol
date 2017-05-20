/**
 * Contract that mint tokens by github commit stats
 * 
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
 
import "CollaborationBank.sol";
import "Controlled.sol";
import "./BountyBank.sol";
import "./GitRepositoryToken.sol";

pragma solidity ^0.4.11;

contract GitRepositoryI is Controlled{
    function claim(address _user, uint _total) returns (bool) ; 
    function setBounty(uint256 _issueId, bool _state, uint256 _closedAt);
    function setBountyPoints(uint256 _issueId,  address _claimer, uint256 _points);
}

contract GitRepository is GitRepositoryI {

    GitRepositoryToken public token;
    CollaborationBank public donationBank;
    BountyBank public bountyBank;
    mapping (address=>uint) donators;

    string public name;
    uint256 public uid;

    function () payable {
        donationBank.deposit();
        donators[msg.sender] += msg.value;
    }

    function GitRepository(uint256 _uid, string _name) {
       uid = _uid;
       name = _name;
       token = new GitRepositoryToken(_name);
       donationBank = new CollaborationBank(token);
       token.linkLocker(donationBank);
       bountyBank = new BountyBank();
    }
    
    //oracle claim request
    function claim(address _user, uint _total) 
     only_owner returns (bool) {
        if(!token.lock() && _user != 0x0){
            token.mint(_user, _total);
            return true;
        }else{
            return false;
        }
    }
    
    function setBounty(uint256 _issueId, bool _state, uint256 _closedAt) only_owner {
        if (_state) bountyBank.open(_issueId);
        else bountyBank.close(_issueId,_closedAt);
    }
    
    function setBountyPoints(uint256 _issueId, address _claimer, uint256 _points) only_owner {
        bountyBank.setClaimer(_issueId,_claimer,_points);
    }   

}

library GitFactory {

    function newGitRepository(uint256 _uid, string _name) returns (GitRepositoryI){
        GitRepository repo = new GitRepository(_uid,_name);
        return repo;
    }

}
