pragma solidity ^0.4.17;

/**
 * @title TokenReceiver
 * @dev ERC223 and ERC677
 */
contract TokenReceiver {
    function tokenFallback(address _from, uint _value, bytes _data) public returns (bool);
}