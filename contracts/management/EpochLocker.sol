pragma solidity ^0.4.11;
/**
 * @title EpochLocker
 * @author Ricardo Guilherme Schmidt
 * Abstract contract that locks and unlock in period of a blocks.
 */
contract EpochLocker {

    uint256 public unlockedLenght; 
    uint256 public lockedLenght;
    
    function EpochLocker(uint256 _unlockedLenght, uint256 _lockedLenght){ 
        unlockedLenght = _unlockedLenght;
        lockedLenght = _lockedLenght;
    }

    function currentEpoch() public constant returns (uint256) {
        return (block.number / (unlockedLenght + lockedLenght)) + 1;        
    }

    function nextLock() constant public returns (uint256) {
        return epochLock(currentEpoch());
    }

    function epochLock(uint256 epoch) constant public returns (uint256) {
         return (epoch * unlockedLenght) + (epoch - 1) * lockedLenght;
    }

    function isLocked() constant public returns (bool locked) {
        locked = nextLock() < block.number;
    }
    
}