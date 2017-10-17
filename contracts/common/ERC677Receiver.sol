pragma solidity ^0.4.14;

/**
 * @title TokenReceiver
 * @dev Used by ERC677
 */
contract TokenReceiver {
    function tokenFallback(address _from, uint _value, bytes _data) public returns (bool);
}