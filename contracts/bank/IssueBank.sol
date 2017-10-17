pragma solidity ^0.4.11;

import "../management/TokenLedger.sol";
import "../common/Controlled.sol";


/**
 * @title IssueBank 
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH) 
 * Enable deposits to be withdrawn by points recievers
 **/
contract IssueBank is Controlled, TokenLedger {
    enum State {OPEN, REFUND, REWARD, FINALIZED }
    State public state;
    uint public points;
    uint public refundNonce;
    mapping (address => Reward) public rewards;
    address public repoOwner;
      
    struct Reward {
        bool active;
        uint points;
    }
     
    modifier onlyRepoOwner{
        require (msg.sender == repoOwner);
        _;
    }   
    
    function IssueBank(address _repoOwner) {
        repoOwner = _repoOwner;
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
    function confirm(address[] _claimers) onlyRepoOwner {
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
    function confirm(address _claimer) onlyRepoOwner {
        require(!rewards[_claimer].active);
        rewards[_claimer].active = true;
        points += rewards[_claimer].points;
    }
    
    /**
     * @notice only repo owner can close deposits and start reward or refund
     * If no points confirmed the system will start refund, otherwise reward
     */
    function close() onlyRepoOwner {
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
     * @notice Withdraw tokens 
     * only avaliable in REWARD state and all points claimed.
     * 
     **/
    function withdraw(address[] _tokens) onlyController {
        require(state == State.FINALIZED);
        uint len = _tokens.length;
        uint amount;
        for (uint i = 0; i < len; i++) {
            ERC20 token = ERC20(_tokens[i]);
            amount = token.balanceOf(this);
            if (amount > 0) {
                withdraw(
                    token,
                    repoOwner,
                    amount,
                    0x0
                );
            }
        }
    }
    /**
     * @notice only controller may kill contract and send all remaining eth and tokens to repo owner
     * This can only be done when all rewards are claimed. 
     **/    
    function kill() onlyController {
        require(state == State.FINALIZED);
        withdraw(tokens);
        selfdestruct(repoOwner);
    }
    /**
     * @dev overwriten to only allow refund in correct state.
     **/
    function refund(address _token) returns (bool success) {
        require(state == State.REFUND);
        success = withdraw(
            _token,
            msg.sender,
            deposits[_token][msg.sender],
            msg.sender
        );
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


/**
 * @title IssueBankFactory
 * @author Ricado Guilherme Schmidt <3esmit>
 **/
contract IssueBankFactory {
 
    /**
     * @notice creates new IssueBank with repoOwner as moderator
     **/
    function create(address repoOwner) returns(IssueBank) {
        IssueBank bank = new IssueBank(repoOwner);
        bank.changeController(msg.sender);
        return bank;
    }   
    
}