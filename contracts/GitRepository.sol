pragma solidity ^0.4.11;
import "./bank/CollaborationBank.sol";
import "./bank/BountyBank.sol";

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
contract GitRepositoryI is Controlled{
    function claim(address _user, uint _total) returns (bool) ; 
    function setBounty(uint256 _issueId, bool _state, uint256 _closedAt);
    function setBountyPoints(uint256 _issueId,  address _claimer, uint256 _points);
}

contract GitRepository is TokenController, GitRepositoryI {

    MiniMeToken public token;
    CollaborationBank public donationBank;
    BountyBank public bountyBank;
    
    string public name;
    uint256 public uid;

    function GitRepository(uint256 _uid, string _name) {
       uid = _uid;
       name = _name;
       bountyBank = new BountyBank();
    }

    function setDonationBank(MiniMeToken token, uint unlocked, uint locked){
        donationBank = new CollaborationBank(token, unlocked, locked);    
    }
    
    //oracle claim request
    function claim(address _user, uint _total) 
     onlyController returns (bool) {
        if(_user != 0x0){
            token.generateTokens(_user, _total);
            return true;
        }else {
            return false;
        }
    }
    
    function setBounty(uint256 _issueId, bool _state, uint256 _closedAt) onlyController {
        if (_state) bountyBank.open(_issueId);
        else bountyBank.close(_issueId,_closedAt);
    }
    
    function setBountyPoints(uint256 _issueId, address _claimer, uint256 _points) onlyController {
        bountyBank.setClaimer(_issueId,_claimer,_points);
    }   

        /// @notice Called when `_owner` sends ether to the MiniMe Token contract
    /// @param _owner The address that sent the ether to create tokens
    /// @return True if the ether is accepted, false if it throws
    function proxyPayment(address _owner) payable returns(bool){}

    /// @notice Notifies the controller about a token transfer allowing the
    ///  controller to react if desired
    /// @param _from The origin of the transfer
    /// @param _to The destination of the transfer
    /// @param _amount The amount of the transfer
    /// @return False if the controller does not authorize the transfer
    function onTransfer(address _from, address _to, uint _amount) returns(bool){}

    /// @notice Notifies the controller about an approval allowing the
    ///  controller to react if desired
    /// @param _owner The address that calls `approve()`
    /// @param _spender The spender in the `approve()` call
    /// @param _amount The amount in the `approve()` call
    /// @return False if the controller does not authorize the approval
    function onApprove(address _owner, address _spender, uint _amount)
        returns(bool){}

}
