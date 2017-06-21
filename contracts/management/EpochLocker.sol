/**
 * Abstract contract that locks and unlock in period of a time.
 * 
 */

import "./Lockable.sol";

pragma solidity ^0.4.11;

contract EpochLocker is Lockable {

    uint256 public unlockedTime = 25 days; 
    uint256 public lockedTime = 5 days; 
    uint256 public constant EPOCH_LENGTH = 30 days;
    
    function currentEpoch() public constant returns(uint256){
        return now / EPOCH_LENGTH + 1;        
    }

    function nextLock() public constant returns (uint256){
        uint256 epoch = currentEpoch();
        return (epoch * unlockedTime) + (epoch - 1) * lockedTime;
    }

    function EpochLocker(uint256 _unlockedTime, uint256 _lockedTime){ 
        unlockedTime = _unlockedTime;
        lockedTime = _lockedTime;
    }

    //update lock value if needed or throw if unexpected lock
    modifier check_lock(bool lockedOnly) {
        if (nextLock() < now) { //is locked!
            if(lockedOnly){ //method allowed when locked
                if (!lock) setLock(true); //storage says other thing, update it.
            }else{
                if (lock) throw; //no need to update storage.
                setLock(true); //update storage
                return; //prevent method from running post states.    
            }
        }
        else { //is not locked!
            if(lockedOnly){ //method allowed when locked
                if (!lock) throw; //unlocked and storage already say so, throw to prevent event flood.
                setLock(false); //update storage
                return; //prevent method from running post states.
            }else{
                if (lock) setLock(false); //storage says other thing, update it.
            }
        }
        _;
    }
    

}