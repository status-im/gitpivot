import "./ERC20.sol";

pragma solidity ^0.4.11;

contract ERC23Receiver {
    function tokenFallback(address _from, uint _value, bytes _data);
}

contract ERC23 is ERC20 { 
    uint256 public decimals;
    string public name;
    string public symbol;
    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);
    function transfer(address _to, uint _value, bytes _data) returns (bool ok);
}