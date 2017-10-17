pragma solidity ^0.4.14;

import "./ERC20.sol";
import "./ERC677Receiver.sol";

contract ERC677 is ERC20 { 
    function transferAndCall(address receiver, uint amount, bytes data) returns (bool success) {
        require(transfer(receiver, amount));
        return _postTransferCall(receiver, amount, data);
    }

    function _postTransferCall(address receiver, uint amount, bytes data) internal returns (bool success) {
        return ERC677Receiver(receiver).tokenFallback(msg.sender, amount, data);
    }
}