pragma solidity ^0.4.11;

import "./bank/CollaborationBank.sol";
import "./bank/BountyBank.sol";
import "./management/Controlled.sol";


contract GitRepositoryI is Controlled {
    function claim(address _user, uint _total) returns (bool);
    function setBounty(uint256 _issueId, bool _state, uint256 _closedAt);
    function setBountyPoints(uint256 _issueId,  address _claimer, uint256 _points);
}


/**
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH) 
 */
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

    function setDonationBank(MiniMeToken _token, uint _epochLenght) public onlyController {
        donationBank = new CollaborationBank(_token, _epochLenght);    
    }
    
    //oracle claim request
    function claim(address _user, uint _total) public onlyController returns (bool) {
        if (_user != 0x0) {
            return token.generateTokens(_user, _total);
        } else {
            return false;
        }
    }
    
    function setBounty(uint256 _issueId, bool _state, uint256 _closedAt) public onlyController {
        if (_state)
            bountyBank.open(_issueId);
        else 
            bountyBank.close(_issueId, _closedAt);
    }
    
    function setBountyPoints(uint256 _issueId, address _claimer, uint256 _points) public onlyController {
        bountyBank.setClaimer(_issueId, _claimer, _points);
    }   

    function proxyPayment(address) public payable returns(bool) {
        return false;
    }

    function onTransfer(address, address, uint) public returns(bool) { 
        return true;
    }

    function onApprove(address, address, uint) public returns(bool) {
        return true;
    }

}