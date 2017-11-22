pragma solidity ^0.4.11;

import "../token/TokenLedger.sol";
import "../common/Controlled.sol";

/**
 * @title IssueBank 
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH) 
 * @dev Model (library) contract to set agreement between a repository owner and GitPivot
 * about the bounty winners.
 **/
contract IssueBankModel is Controlled, TokenLedger {

    address public owner; //repository owner
    mapping (address => Reward) public rewards;  //bounty winners candidates
    uint public points; //remaining points to be claimed
    State public state; //current issue state

    enum State { OPEN, REFUND, REWARD, FINALIZED }
    
    struct Reward {
        bool active; // repository owner can activate
        uint points;
    }
     
    modifier onlyOwner{
        require (msg.sender == owner);
        _;
    }   
    
    /**
     * @dev Model Constructor: Generates a locked state for model being unusable
     **/
    function IssueBankModel() public {
        owner = 0x0;
    }

    /**
     * @dev Instance Constructor: Actual agreement logic initialization.
     * @param _owner Repository owner which will accept bounty winners and finalize issue.
     **/
    function IssueBank(address _owner) public {
        require(controller == 0x0); 
        controller = msg.sender;
        owner = _owner;
        state = State.OPEN;
    }

    /**
     * @notice deposit ether in bank
     **/
    function () payable {
        deposits[msg.sender][0x0] += msg.value;
    }
    
    /**
     * @notice claim all watched tokens based on user points;
     */
    function reward() {
        _reward(tokens);
    }
    
    /**
     * @notice Useful if some token is throwing on transfer.
     * @param _tokens the array of desired watched tokens. If token is not watched it will ignore..
     */
    function rewardEthAnd(address[] _tokens) {
        _reward(_tokens);
    }


    /**
     * @notice Repository owner can replace his address 
     * @param _newOwner 
     **/
    function updateOwner(address _newOwner) onlyOwner { 
        require(_newOwner != 0x0);
        owner = _newOwner;
    }

    /**
     * @notice only contoller may set reward to a single address. 
     * @param _claimer the beneficiary
     * @param _points amount of points
     **/
    function setReward(address _claimer, uint _points) onlyController { 
        require(state == State.OPEN);
        assert(!rewards[_claimer].active);
        rewards[_claimer].points = _points;
    }
    
    /**
     * @notice only contoller may set reward to an array of addresses. 
     * @param _claimers the array of beneficiaries
     * @param _points the array of amount of points
     **/
    function setReward(address[] _claimers, uint[] _points) onlyController { 
        require(state == State.OPEN);
        uint len = _claimers.length;
        for (uint i = 0; i < len; i++) {
            address _claimer = _claimers[i];
            assert(!rewards[_claimer].active);
            rewards[_claimer].points = _points[i];
        }
    }
    
    /**
     * @notice only the repo owner may confirm reward of addresses
     * @param _claimers array of addresses that are eligible to reward
     **/
    function confirm(address[] _claimers) onlyOwner {
        uint len = _claimers.length;
        uint nPoints = 0;
        for (uint i = 0; i < len; i++) {
            address _claimer = _claimers[i];
            require(!rewards[_claimer].active);
            rewards[_claimer].active = true;
            nPoints += rewards[_claimer].points;
        }
        points += nPoints;
    }
    
    /**
     * @notice only the repo owner may confirm reward of single address
     * @param _claimer the address that is eligible to reward
     **/
    function confirm(address _claimer) onlyOwner {
        require(!rewards[_claimer].active);
        rewards[_claimer].active = true;
        points += rewards[_claimer].points;
    }
    
    /**
     * @notice only repo owner can close deposits and start reward or refund
     * If no points confirmed the system will start refund, otherwise reward
     */
    function close() onlyOwner {
        require(state == State.OPEN);
        state = points > 0 ? State.REWARD : State.REFUND;
    }
    
    /**
     * @notice Set a new list of tokens to be rewarded. 
     * User can still reward tokens not listed if he calls `rewardEthAnd(address[]`
     * providing a list including unlisted tokens.
     * To list a new token use `watch(address)` that will update the balance aswell
     * @param _tokens the list of new tokens. 
     * 
     */
    function setTokenList(address[] _tokens) onlyController {
        tokens = _tokens;
    }
    
    /**
     * @notice withdraw remaining tokens and eth send them to repoOwner
     *         this might be a case when some tokens were 'forgotten'
     *         or simply sent after finalized. 
     * @param _tokens the list of tokens to withdraw.
     **/
    function withdraw(address[] _tokens) onlyController {
        require(state == State.FINALIZED);
        if (this.balance > 0) {
            owner.send(this.balance);
        }
        uint len = _tokens.length;
        uint amount;
        for (uint i = 0; i < len; i++) {
            address token = _tokens[i];
            amount = updateInternalBalance(token);
            if (amount > 0) {
                withdraw(
                    token,
                    owner,
                    amount,
                    0x0
                );
            }
        }
    }

    /**
     * @dev overwriten to only allow refund in correct state and to refund eth
     **/
    function refund(address _token) returns (bool success) {
        require(state == State.REFUND);
        if(_token == 0x0){
            uint v = deposits[0x0][msg.sender];
            if (v > 0) {
                delete deposits[0x0][msg.sender];
                success = msg.sender.send(v);
            }
        } else {
            success = withdraw(
                _token,
                msg.sender,
                deposits[_token][msg.sender],
                msg.sender
            );
        }
    }
    
   /**
     * @dev register the deposit to refundings
     **/
    function register(
        address _token,
        address _sender,
        uint _amount,
        bytes _data
    )
        internal 
    {
        require(state == State.OPEN);
        super.register(
            _token,
            _sender,
            _amount,
            _data
        );
    }
    
    function _reward(address[] _tokens) internal {
        require(state == State.REWARD);
        address dest = msg.sender;
        require(rewards[dest].active);
        uint _rewardPoints = rewards[dest].points;
        delete rewards[dest];
        require(_rewardPoints > 0);
        uint _outReward;
        uint len = _tokens.length;
        for (uint i = 0; i < len; i++) {
            address tokenAddr = _tokens[i];
            _outReward = tokenBalances[tokenAddr];
            if (_outReward > 0) {
                _outReward = calculeReward(_outReward, _rewardPoints);
            }
            if (_outReward > 0) {
                withdraw(
                    tokenAddr,
                    dest,
                    _outReward,
                    0x0
                );
            }
        }
        _outReward = this.balance;
        if (_outReward > 0) {
            _outReward = (_outReward / points) * _rewardPoints;
        }
        if (_outReward > 0) {
            withdraw(
                0x0,
                dest,
                _outReward,
                0x0
            );
        }
        points -= _rewardPoints;
        if (points == 0) {
            state = State.FINALIZED;
        }
    }
    
    /**
     * @dev amplifies small token balances to divide points 
     **/
    function calculeReward(uint _balance, uint _rewardPoints)
        internal 
        constant 
        returns (uint _reward)
    {
        uint amplifier = 1;
        while (_balance * amplifier < points) {
            amplifier *= 10;
        }
        _reward = (((_balance*amplifier) / points) * _rewardPoints) / amplifier;
    }
    
    
}