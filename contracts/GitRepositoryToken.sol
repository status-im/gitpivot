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

import "./token/LockerToken.sol";
import "./management/Controlled.sol";

pragma solidity ^0.4.11;

contract GitRepositoryToken is LockerToken {

    function GitRepositoryToken(string _repository) AbstractToken(0, _repository, "GIT"){
    }
    
    function mint(address _who, uint256 _value)
     onlyController when_locked(false) {
        _mint(_who,_value);
    }

}
