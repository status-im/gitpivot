
pragma solidity ^0.4.11;

/** 
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)
 * @title RegistryIndex
 * @dev abstract registry index handling.
 */
contract RegistryIndex {

    string private constant STR_PREFIX = "name";
    string private constant ADDR_PREFIX = "address";
    mapping (bytes32 => uint256) private indexes; 
    mapping (uint256 => Registry) public registry;

    struct Registry {
        address addr; 
        string name; 
    }

    function getAddr(uint256 _id) public constant returns(address addr) {
        return registry[_id].addr;
    }

    function getName(address _addr) public constant returns(string name) {
        return registry[getId(_addr)].name;
    } 

    function getAddr(string _name) public constant returns(address addr) {
        return registry[getId(_name)].addr;
    }

    function getId(address _addr) public constant returns(uint256 id){
        return indexes[keccak256(ADDR_PREFIX, _addr)];
    } 

    function getId(string _name) public constant returns(uint256 id) {
        return indexes[keccak256(STR_PREFIX, _name)];
    }

    function setRegistry(uint _uid, address _addr, string _name) internal {
        if (registry[_uid].addr != 0x0) {
            delete indexes[keccak256(ADDR_PREFIX, _addr)];
            delete indexes[keccak256(STR_PREFIX, _name)];
        }
        indexes[keccak256(ADDR_PREFIX, _addr)] = _uid;
        indexes[keccak256(STR_PREFIX, _name)] = _uid;
        registry[_uid] = Registry(
            {
                addr: _addr,
                name: _name
            }
        ); 
    }
    
    function setIndex(uint256 _uid, address _addr) internal {
        indexes[keccak256(ADDR_PREFIX, _addr)] = _uid;
    }

    function setIndex(uint256 _uid, string _name) internal {
        indexes[keccak256(STR_PREFIX, _name)] = _uid;
    }
    
    function clearIndex(address _addr) internal {
        delete indexes[keccak256(ADDR_PREFIX, _addr)];
    }

    function clearIndex(string _name) internal {
        delete indexes[keccak256(STR_PREFIX, _name)];   
    }

    function updateIndex(bytes32 _old, bytes32 _new) private {
        if (_old != _new) {
            indexes[_new] = indexes[_old];   
            delete indexes[_old];
        }
    }

    function updateIndex(string _old, string _new) internal {
        updateIndex(keccak256(STR_PREFIX, _old), keccak256(STR_PREFIX, _new));
    }

    function updateIndex(address _old, address _new) internal {
        updateIndex(keccak256(ADDR_PREFIX, _old), keccak256(ADDR_PREFIX, _new));
    }
}
