contract NameRegistry{
    function getAddr(uint256 _id) public constant returns(address addr);
    function getAddr(string _name) public constant returns(address addr);
    function getName(address _addr) public constant returns(string name);
}