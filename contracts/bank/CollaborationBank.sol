pragma solidity ^0.4.10;

import "../token/MiniMeToken.sol";
import "../management/EpochLocker.sol";

contract CollaborationBank is  EpochLocker, Controlled {
    
    MiniMeToken public token;
    //used for calculating balance and for checking if account withdrawn
    uint256 public currentPayEpoch;
    uint256 public pendingBalance = 0;
    //stores the balance from the lock time
    mapping (uint => uint) public epochBalances;
    //used for checking if account withdrawn
    mapping (address => uint) lastPaidOutEpoch;
    //events
    
    function CollaborationBank(MiniMeToken _token,uint unlocked, uint locked) EpochLocker(unlocked, locked) {
        token = _token;
    }
    
    function reconfigure(MiniMeToken _token, uint unlocked, uint locked) onlyController {
        token = _token;
        unlockedLenght = unlocked;
        lockedLenght = locked;
    }

    //check overflow in multiply
    function safeMultiply(uint256 _a, uint256 _b) private {
        if (!(_b == 0 || ((_a * _b) / _b) == _a)) throw;
    }
    
    //withdraw if locked and not paid, updates epoch
    function withdrawal()
     external {
        if(this.balance == 0) throw; 
        if(!isLocked()) throw;
        uint _currentEpoch = currentEpoch();

        if(epochBalances[_currentEpoch] == 0){
            uint _thisEpochBalance = this.balance - pendingBalance;
            epochBalances[_currentEpoch] = _thisEpochBalance;
            pendingBalance += _thisEpochBalance;
        } 
        
        uint256 _lockBlock;
        uint256 _tokenBalance;
        uint256 _tokenSupply;
        uint _lastPayout = lastPaidOutEpoch[msg.sender];
        uint _amount = 0;
        for(_lastPayout = _lastPayout+1; _lastPayout > _currentEpoch; _lastPayout++){
            uint _epochBalance = epochBalances[_lastPayout];
            if(_epochBalance > 0){
                _lockBlock = epochLock(_lastPayout);
                _tokenBalance = token.balanceOfAt(msg.sender, _lockBlock);
                if(_tokenBalance > 0) {
                    _tokenSupply = token.totalSupplyAt(_lockBlock);
                    safeMultiply(_tokenBalance, _epochBalance);
                    _amount += _tokenBalance * _epochBalance / _tokenSupply;
                }
                if(msg.gas < 10000) break;
            }
        }
        lastPaidOutEpoch[msg.sender] = _lastPayout; 
        if (_amount > 0){ 
            pendingBalance -= _amount;
            msg.sender.transfer(_amount);
        }
    }

    //if this coin owns tokens of other CollaborationBank, allow withdraw
    function withdrawalFrom(CollaborationBank _otherCollaborationToken) {
        _otherCollaborationToken.withdrawal();
    }


}
