pragma solidity ^0.4.11;


contract IGitRepository {
    function claim(address _user, uint _total) returns (bool);
    function setBounty(uint256 _issueId, bool _state, uint256 _closedAt);
    function setBountyPoints(uint256 _issueId,  address _claimer, uint256 _points);
}