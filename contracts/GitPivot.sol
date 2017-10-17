pragma solidity ^0.4.10;

import "./common/Controlled.sol";
import "./PointsOracle.sol";
import "./UserOracle.sol";
import "./RepositoryOracle.sol";


/**
 * @title GitPivot.sol
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)
 */
contract GitPivot is Controlled, DGitI {

    UserOracle public userOracle;
    RepositoryOracle public repositoryOracle;
    PointsOracle public pointsOracle;

    mapping (uint256 => Repository) repositories;
    mapping (uint256 => mapping (uint256 => uint256)) pending;

    address public newContract;

    modifier package {
        require(msg.sender == address(pointsOracle));
        _;
    }

    modifier onlyUpgrading {
        require(newContract != 0);
        _;
    }

    struct Repository {
        string head;
        string tail;
        mapping (string => string) pending;
    }

    function getRepository(string _repository, string _branch) public constant returns (uint repoId) {
        repoId = repositoryOracle.getId(_repository);
        require(repoId != 0);
        require(repositoryOracle.getBranch(repoId) == keccak256(_branch));
    }

    function start(string _repository, string _branch, string _token) public payable {
        getRepository(_repository, _branch);
        pointsOracle.start.value(msg.value)(_repository, _branch, _token);
    }
    
    function update(string _repository, string _branch, string _token) public payable {
        uint256 repoId = getRepository(_repository, _branch);
        pointsOracle.update.value(msg.value)(
            _repository,
            _branch,
            repositories[repoId].head,
            _token
        );
    }

    function resume(
        string _repository,
        string _branch,
        string _pendingTail,
        string _token
    )
        public
        payable
    {
        uint256 repoId = getRepository(_repository, _branch);
        string memory claimedCommit = repositories[repoId].pending[_pendingTail];
        require(bytes(claimedCommit).length != 0);
        delete repositories[repoId].pending[_pendingTail];
        pointsOracle.resume.value(msg.value)(
            _repository,
            _branch,
            _pendingTail,
            claimedCommit,
            _token
        );
    }

    function rtail(string _repository, string _branch, string _token) public payable {
        uint256 repoId = getRepository(_repository, _branch);
        pointsOracle.rtail.value(msg.value)(
            _repository,
            _branch,
            repositories[repoId].tail,
            _token
        );
    }
    
    function issue(string _repository, string _issue, string _token) public payable {
        pointsOracle.issue.value(msg.value)(_repository, _issue, _token);
    }
    
    //claims pending points
    function claimPending(uint _repoId, uint _userId) public {
        GitRepositoryI repoaddr = GitRepositoryI(repositoryOracle.getAddr(_repoId));
        uint total = pending[_userId][_repoId];
        delete pending[_userId][_repoId];
        require(repoaddr.claim(userOracle.getAddr(_userId), total));
    }
    
    function setUserOracle(address _userOracle) public onlyController {
       userOracle = UserOracle(_userOracle);
    }

    function setRepositoryOracle(address _repoOracle) public onlyController {
       repositoryOracle = RepositoryOracle(_repoOracle);
    }
    
    function setPointsOracle(address _pointsOracle) public onlyController {
       pointsOracle = PointsOracle(_pointsOracle);
    }
    
    
    function upgradeContract(address _newContract) public onlyController {
        require(_newContract != 0);
        userOracle.changeController(_newContract);
        repositoryOracle.changeController(_newContract);
        pointsOracle.changeController(_newContract);
        newContract = _newContract;
        if (this.balance > 0) {
            _newContract.transfer(this.balance);
        }
    }

    function upgrade(uint[] _repoIds) public onlyUpgrading onlyController {
        uint len = _repoIds.length;
		for (uint i = 0; i < len; i++) {
            Controlled(repositoryOracle.getAddr(_repoIds[i])).changeController(newContract);
        }
    }
    
    function pendingScan(uint256 _projectId, string _lastCommit, string _pendingTail) public package {
        repositories[_projectId].pending[_pendingTail] = _lastCommit;
    }
    
    function setHead(uint256 _projectId, string _head) public package {
        repositories[_projectId].head = _head;
    }

    function setTail(uint256 _projectId, string _tail) public package {
        repositories[_projectId].tail = _tail;
    }

    function setIssue(
        uint256 _projectId,
        uint256 _issueId,
        bool _state,
        uint256 _closedAt
    )
        public
        package
    {
        GitRepositoryI repo = GitRepositoryI(repositoryOracle.getAddr(_projectId));
        repo.setBounty(_issueId, _state, _closedAt);
    }

    function setIssuePoints(
        uint256 _projectId,
        uint256 _issueId,
        uint256[] _userId,
        uint256[] _points
    ) 
        public 
        package 
    {
        GitRepositoryI repo = GitRepositoryI(repositoryOracle.getAddr(_projectId));
        uint len = _userId.length;
        for (uint i = 0; i < len; i++) {
            address addr = userOracle.getAddr(_userId[i]);
            repo.setBountyPoints(_issueId, addr, _points[i]);
        }
    }

    function newPoints(uint _repoId, uint[] _userIds, uint[] _points) public package {
        GitRepositoryI repo = GitRepositoryI(repositoryOracle.getAddr(_repoId));
        uint len = _userIds.length;
        for (uint i = 0; i < len; i++) {
            uint _userId = _userIds[i];
            uint _uPoints = _points[i];
            address addr = userOracle.getAddr(_userId);
            if (addr == 0x0 || !repo.claim(addr, _uPoints)) {
                pending[_userId][_repoId] += _uPoints;
            }
        }
    }

}