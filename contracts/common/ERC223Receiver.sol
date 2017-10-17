pragma solidity ^0.4.14;

/**
 * @title TokenReceiver
 * @dev Used by ERC223
 */
contract ERC223Receiver {
    function tokenFallback(address _from, uint _value, bytes _data);
}