import "./Owned.sol";

pragma solidity ^0.4.8;

contract Lockable {
    bool public lock = true;
    event Locked(bool lock);
    
    function setLock(bool _lock) internal {
        Locked(_lock);
        lock = _lock;
    }
    
}
