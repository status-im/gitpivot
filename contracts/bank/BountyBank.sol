pragma solidity ^0.4.11;

import "../common/Controlled.sol";

/**
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)
 */
contract BountyBank is Controlled {
    
    enum State {CLOSED, OPEN, CLAIMED}
    
    struct Bounty {
        State state;
        uint closedAt;
        mapping (address => uint) deposits;
        mapping (address => uint) claimers;
        uint balance;
        uint points;
     }
     
    mapping (uint => Bounty) bounties;
    uint count = 0;

    function deposit(uint num) payable {
        require(bounties[num].state == State.OPEN);
        require(msg.value > 0);
        bounties[num].deposits[msg.sender] += msg.value;
        bounties[num].balance += msg.value;
    }

    function withdraw(uint num) {
        uint value = bounties[num].deposits[msg.sender];
        require(bounties[num].state == State.OPEN && value > 0);
        delete bounties[num].deposits[msg.sender];
        msg.sender.transfer(value);
    }

    function open(uint num) onlyController {
        require(bounties[num].state != State.CLAIMED);
        bounties[num].state = State.OPEN;
    }

    function setClaimer(uint num, address claimer, uint points) onlyController {
        require(bounties[num].state != State.CLAIMED);
        bounties[num].claimers[claimer] += points;
        bounties[num].points += points;
    }

    function close(uint num, uint _closedAt) onlyController {
        require(bounties[num].state != State.CLAIMED);
        bounties[num].state = State.CLOSED;
        bounties[num].closedAt = _closedAt;
    }
     
    function claim(uint num) {
        require (bounties[num].state != State.OPEN);
        uint totalPoints = bounties[num].points;
        require (totalPoints > 0);
        uint points = bounties[num].claimers[msg.sender];
        require (points > 0);
        delete bounties[num].claimers[msg.sender];
        uint award = (bounties[num].balance / totalPoints)*points;
        bounties[num].points -= points;
        bounties[num].balance -= award;
        msg.sender.transfer(award);
    }

}