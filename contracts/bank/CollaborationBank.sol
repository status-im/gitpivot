pragma solidity ^0.4.10;

import "../token/MiniMeToken.sol";


/**
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)
 */
contract CollaborationBank is Controlled {
    
    MiniMeToken public token;
    //used for calculating balance and for checking if account withdrawn
    uint256 public currentPayEpoch;
    uint256 public pendingBalance = 0;
    //stores the balance from the lock time
    mapping (uint => uint) public epochBalances;
    //used for checking if account withdrawn
    mapping (address => uint) lastPaidOutEpoch;
    //events
    
    uint256 public epochLenght; 
    uint256 public firstEpoch; 

    function CollaborationBank(MiniMeToken _token, uint _epochLenght) {
        epochLenght = _epochLenght;
        firstEpoch = currentEpoch();
        token = _token;
    }
    
    function reconfigure(MiniMeToken _token) public onlyController {
        token = _token;
    }

    //check overflow in multiply
    function safeMultiply(uint256 _a, uint256 _b) private constant {
        require (_b == 0 || ((_a * _b) / _b) == _a);
    }
    
    //withdraw if locked and not paid, updates epoch
    function withdrawal() external {
        require(this.balance > 0); 
        uint _currentEpoch = currentEpoch();

        //runs when epoch changed, updates the epoch balance
        if (epochBalances[_currentEpoch] == 0) {
            uint _thisEpochBalance = this.balance - pendingBalance;
            epochBalances[_currentEpoch] = _thisEpochBalance;
            pendingBalance += _thisEpochBalance;
        } 
        
        uint256 _epochEnd;
        uint256 _tokenBalance;
        uint256 _tokenSupply;
        uint _lastPayout = lastPaidOutEpoch[msg.sender];
        uint _amount = 0;
        for (_lastPayout = _lastPayout+1; _lastPayout > _currentEpoch; _lastPayout++) {
            uint _epochBalance = epochBalances[_lastPayout];
            if (_epochBalance > 0) {
                _epochEnd = epochEnd(_lastPayout);
                _tokenBalance = token.balanceOfAt(msg.sender, _epochEnd);
                if (_tokenBalance > 0) {
                    _tokenSupply = token.totalSupplyAt(_epochEnd);
                    safeMultiply(_tokenBalance, _epochBalance);
                    _amount += _tokenBalance * _epochBalance / _tokenSupply;
                }
                if (msg.gas < 10000)
                    break;
            }
        }
        lastPaidOutEpoch[msg.sender] = _lastPayout; 
        if (_amount > 0) { 
            pendingBalance -= _amount;
            msg.sender.transfer(_amount);
        }
    }

    /**
     * @dev gets the current epoch
     */
    function currentEpoch() public constant returns (uint256) {
        return (block.number / epochLenght) + 1;
    }

    /**
     * @dev gets the block number of `epoch` end
     */
    function epochEnd(uint256 epoch) public constant returns (uint256) {
        return (epoch * epochLenght);
    }

    //if this coin owns tokens of other CollaborationBank, allow withdraw
    function withdrawalFrom(CollaborationBank _otherCollaborationToken) public {
        _otherCollaborationToken.withdrawal();
    }


}
