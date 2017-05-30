/**
 * Abstract contract to accept lock and linked locker. 
 * 
 * By Ricardo Guilherme Schmidt
 * Released under GPLv3 License
 */

import "./AbstractToken.sol";
import "../management/Lockable.sol";
import "../management/Controlled.sol";

pragma solidity ^0.4.11;

contract LockerToken is AbstractToken, Lockable, Controlled {
    Lockable public locker = this;

    function unlinkLocker() onlyController {
        locker = this;
    }
    function linkLocker(Lockable _locker) onlyController {
        locker = _locker;
    }
    function setlock(bool _lock) onlyController {
        setLock(_lock);
    }
    
    modifier when_locked(bool value){
        if (lock != value && locker.lock() != value) throw;
        _;
    }
    
    //overwrite not allow transfer during lock
    function transfer(address _to, uint256 _value) when_locked(true)
     returns (bool ok) {
        return super.transfer(_to,_value);
    }
    
    //overwrite not allow transfer during lock
    function transferFrom(address _from, address _to, uint256 _value) when_locked(true)
     returns (bool ok)  {
        return super.transferFrom(_from,_to,_value);
    }
    
}
