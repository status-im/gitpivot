import "./ERC23.sol";

pragma solidity ^0.4.11;

/**
 * AbstractToken ECR20-compliant token contract
 * Child should implement initial supply or minting and overwite base
 * Based on BasicCoin by Parity Team (Ethcore), 2016.
 * @author Ricardo Guilherme Schmidt
 * Released under the Apache Licence 2.
 */
contract AbstractToken is ERC23 {

    mapping (address => Account) private accounts; 

    function AbstractToken(uint256 _decimals, string _name, string _symbol){
        decimals = _decimals;
        name = _name;
        symbol = _symbol;
    }
    
    struct Account {
        uint256 balance;
        mapping (address => Allowance) allowanceOf;
    }
    
    /// @dev `Allowance` structure holds block number of allowance spent 
    ///  and the amount allowed
    struct Allowance { 
        
        // `amount` to be spent
        uint amount;

        // `blockSpent` is for blocking change of allowance near spent block 
        //  to prevent race conditions 
        uint timeSpent;
    }
    
    // the balance should be available
    modifier when_owns(address _owner, uint256 _amount) {
        if (balanceOf(_owner) < _amount) throw;
        _;
    }

    // an allowance should be available
    modifier when_has_allowance(address _owner, address _spender, uint256 _amount) {
        if (allowance(_owner,_spender) < _amount) throw;
        _;
    }

    //child may override this function to trigger changes in balance dependent storage
    function _balanceUpdated(address _from) 
     internal {
        
    }
    
    // add tokens to a balance
    function _mint(address _to, uint256 _value)
     internal {
        if (totalSupply + _value < totalSupply) throw; //overflow: maximum totalSupply in the current base;
        Transfer(0x0, _to, _value);
        totalSupply += _value;
        accounts[_to].balance += _value; 
        if(isContract(_to)){
            ERC23Receiver(_to).tokenFallback(0x0, _value, new bytes(0));
        }
        _balanceUpdated(_to);
    }

    // remove tokens from a balance    
    function _destroy(address _from, uint256 _value)
     internal {
        Transfer(_from, 0x0, _value);
        totalSupply -= _value;
        accounts[_from].balance -= _value;   
        if(accounts[_from].balance == 0){ 
            delete accounts[_from]; //to reduce gas in mapping accounts
        }
        _balanceUpdated(_from);
    }

    // balance of a specific address
    function balanceOf(address _who) 
     constant 
     returns (uint256) {
        return accounts[_who].balance;
    }

    // transfer
    function transfer(address _to, uint256 _value) 
     when_owns(msg.sender, _value) 
     returns (bool) {
        return _transfer(msg.sender, _to, _value, new bytes(0));
    }
    
    function transfer(address _to, uint256 _value, bytes _data) when_owns(msg.sender, _value) 
     returns (bool) {
         return _transfer(msg.sender, _to,_value, _data);
    }
     
    // transfer via allowance
    function transferFrom(address _from, address _to, uint256 _value) 
     when_owns(_from, _value) 
     when_has_allowance(_from, msg.sender, _value) 
     returns (bool) {
        accounts[_from].allowanceOf[msg.sender].amount -= _value;
        accounts[_from].allowanceOf[msg.sender].timeSpent = now;
        _transfer(_from, _to, _value, new bytes(0));
        return true;
    }

    // set allowance
    function approve(address _spender, uint256 _totalAllowed) 
     returns (bool) {
        Approval(msg.sender, _spender, _totalAllowed);
        if (_totalAllowed != 0 && now - accounts[msg.sender].allowanceOf[_spender].timeSpent < 30 minutes) throw;
        if (_totalAllowed > 0){ 
            accounts[msg.sender].allowanceOf[_spender].amount = _totalAllowed;
        } else {
            delete accounts[msg.sender].allowanceOf[_spender];
        }
        return true;
    }
    
    function approveAndCall(address _spender, uint256 _totalAllowed, bytes _extraData)
     returns (bool) {
        if(!approve(_spender,_totalAllowed)) throw;
         ApproveAndCallFallBack(_spender).receiveApproval(
            msg.sender,
            _totalAllowed,
            this,
            _extraData
        );
        return true;
    } 
    
    // available allowance
    function allowance(address _owner, address _spender) 
     constant 
     returns (uint256) {
        return accounts[_owner].allowanceOf[_spender].amount;
    }

    // transfer
    function _transfer(address _from, address _to, uint256 _value, bytes _data) 
     internal
     returns (bool) {
        Transfer(_from, _to, _value);
        accounts[_from].balance -= _value;
        accounts[_to].balance += _value;
        _balanceUpdated(_from);
        _balanceUpdated(_to);
        if(isContract(_to)){
            ERC23Receiver(_to).tokenFallback(_from, _value, _data);
        }
        return true;
    }

  //assemble the given address bytecode. If bytecode exists then the _addr is a contract.
    function isContract(address _addr) internal returns (bool is_contract) {
        uint length;
        assembly {
            //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
        if(length>0) {
            return true;
        }
        else {
            return false;
        }
    }
    
}
