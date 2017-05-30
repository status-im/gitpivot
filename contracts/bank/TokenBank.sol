import "../token/ERC23.sol";

pragma solidity ^0.4.11;

/**
 * @title TokenBank 
 * @author Ricardo Guilherme Schmidt <3esmit>
 * Abstract contract for deposit and withdraw of ETH and ERC20/23 Tokens
 **/
contract TokenBank is ERC23Receiver, ApproveAndCallFallBack {
    
    event Withdrawn(address reciever, uint amount);
    event Deposited(address sender, uint value);
    event TokenWithdrawn(address token, address reciever, uint amount);
    event TokenDeposited(address token, address sender, uint value);
    
    mapping (uint => Deposit) public deposits;
    mapping (address => uint) public tokenBalances;
    address[] public tokens;

    uint public nonce;
    
    struct Deposit {
        address sender;
        address token;
        uint amount;
    }
    
    /**
     * @notice deposit ether in bank
     * @return reciept that can be used for refund
     **/
    function deposit() payable returns (uint receipt) {
        address sender = msg.sender;
        uint amount = msg.value;
        if(amount > 0){
            return _deposited(0x0, sender, amount);
        }
    }
    
    /**
     * @notice deposit a ERC20 token. The amount of deposit is the allowance set to this contract.
     * @param _tokenAddr the token contract address
     * @return reciept that can be used for refund
     **/    
    function tokenDeposit(address _tokenAddr) returns (uint reciept) {
        address sender = msg.sender;
        ERC20 token = ERC20(_tokenAddr);
        uint amount = token.allowance(sender, this);
        if(amount == 0) throw;
        uint _nonce = nonce;
        if(!token.transferFrom(sender, this, amount)) throw;
        if(!token.approve(this, amount)) throw;
        if(nonce == _nonce){
            reciept = _deposited(_tokenAddr, sender, amount);
        }else{
            reciept = _nonce; //ERC23 executed _deposited tokenFallback by
        }
    }
    
    /**
     * @notice watches for balance in a token contract
     * @param _tokenAddr the token contract address
     **/   
    function watch(address _tokenAddr){
        bool neverSeen = false;
        if(tokenBalances[_tokenAddr] == 0) neverSeen = true;
        uint amount = ERC20(_tokenAddr).balanceOf(this);
        if(amount > 0){
            if(!ERC20(_tokenAddr).approve(this, amount)) throw;
            if(neverSeen) tokens.push(_tokenAddr);
            tokenBalances[_tokenAddr] = amount;
        }
    }
    
    /**
     * @notice refunds a deposit.
     * @param _nonce the reciept you want to refund
     **/   
    function refund(uint _nonce) returns (bool) {
        if(msg.sender != deposits[_nonce].sender) throw;
        uint amount = deposits[_nonce].amount;
        address token = deposits[_nonce].token;
        delete deposits[_nonce];
        if(token == 0x0){
            withdraw(msg.sender,amount);
        } else {
            withdraw(ERC20(token), msg.sender, amount);
        }
        return true;
    }

    /**
     * @notice ERC23 Token fallback
     * @param _from address incoming token
     * @param _amount incoming amount
     **/    
    function tokenFallback(address _from, uint _amount, bytes) {
        _deposited(msg.sender, _from, _amount);
    }
    
    /** 
     * @notice Called MiniMeToken approvesAndCall to this contract
     * @param _from address incoming token
     * @param _amount incoming amount
     * @param _token the token contract address
     */ 
    function receiveApproval(address _from, uint256 _amount, address _token, bytes){
        _deposited(_token, _from, _amount);
    }
    
    
    /**
     * @dev register the deposit to refundings
     **/
    function _deposited(address _tokenAddr, address _sender, uint _amount)
     internal returns (uint receipt) {
        if(_tokenAddr != 0x0){
            TokenDeposited(_tokenAddr, _sender, _amount);
            if(tokenBalances[_tokenAddr] == 0){
                tokens.push(_tokenAddr);  
                tokenBalances[_tokenAddr] = ERC20(_tokenAddr).balanceOf(this);
            }else{
                tokenBalances[_tokenAddr] += _amount;
            }
        }else{
            Deposited(_sender, _amount);
        }
        receipt = nonce;
        nonce++;
        deposits[receipt] = Deposit({sender: _sender, amount: _amount, token: _tokenAddr});
    }
    
    
    /**
     * @dev withdraw amount wei to dest
     **/
    function withdraw(address _dest, uint _amount)
     internal {
        _dest.transfer(_amount);
        Withdrawn(msg.sender, _amount);
    }
    
    /**
     * @dev withdraw token amount to dest
     **/
    function withdraw(address _tokenAddr, address _dest, uint _amount)
     internal {
        if(!ERC20(_tokenAddr).transferFrom(this, _dest, _amount)) throw;
        tokenBalances[_tokenAddr] -= _amount;
        TokenWithdrawn(_tokenAddr, _dest, _amount);
    }
    
}
