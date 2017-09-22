pragma solidity ^0.4.10;

import "./management/Controlled.sol";
import "./GHPoints.sol";
import "./GHUserReg.sol";
import "./GHRepoReg.sol";



/**
 * @title GitHubOracle.sol
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)]
 */
contract GitHubOracle is Controlled, DGitI {

    GitHubUserReg public userReg;
    GitHubRepositoryReg public repositoryReg;
    GitHubPoints public gitHubPoints;

    mapping (uint256 => Repository) repositories;
    mapping (uint256 => mapping (uint256 => uint256)) pending;

    address public newContract;

    modifier package {
        require(msg.sender == address(gitHubPoints));
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
        repoId = repositoryReg.getId(_repository);
        require(repoId != 0);
        require(repositoryReg.getBranch(repoId) == keccak256(_branch));
    }

    function start(string _repository, string _branch, string _token) public payable {
        getRepository(_repository, _branch);
        gitHubPoints.start.value(msg.value)(_repository, _branch, _token);
    }
    
    function update(string _repository, string _branch, string _token) public payable {
        uint256 repoId = getRepository(_repository, _branch);
        gitHubPoints.update.value(msg.value)(
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
        gitHubPoints.resume.value(msg.value)(
            _repository,
            _branch,
            _pendingTail,
            claimedCommit,
            _token
        );
    }

    function rtail(string _repository, string _branch, string _token) public payable {
        uint256 repoId = getRepository(_repository, _branch);
        gitHubPoints.rtail.value(msg.value)(
            _repository,
            _branch,
            repositories[repoId].tail,
            _token
        );
    }
    
    function issue(string _repository, string _issue, string _token) public payable {
        gitHubPoints.issue.value(msg.value)(_repository, _issue, _token);
    }
    
    //claims pending points
    function claimPending(uint _repoId, uint _userId) public {
        GitRepositoryI repoaddr = GitRepositoryI(repositoryReg.getAddr(_repoId));
        uint total = pending[_userId][_repoId];
        delete pending[_userId][_repoId];
        require(repoaddr.claim(userReg.getAddr(_userId), total));
    }
    
    function initRegs() public onlyController {
        if (address(userReg) == 0) {
            userReg = GHUserReg.create();
        }
        if (address(repositoryReg) == 0) {
            repositoryReg = GHRepoReg.create();
        }
    }

    function setPointsScript(string _arg) public onlyController {
        if (address(gitHubPoints) == 0) {
            gitHubPoints = GHPoints.create(_arg);
        } else {
            gitHubPoints.setScript(_arg);
        }
    }
    
    function upgradeContract(address _newContract) public onlyController {
        require(_newContract != 0);
        userReg.changeController(_newContract);
        repositoryReg.changeController(_newContract);
        gitHubPoints.changeController(_newContract);
        newContract = _newContract;
        if (this.balance > 0) {
            _newContract.transfer(this.balance);
        }
    }

    function upgrade(uint[] _repoIds) public onlyUpgrading onlyController {
        uint len = _repoIds.length;
		for (uint i = 0; i < len; i++) {
            Controlled(repositoryReg.getAddr(_repoIds[i])).changeController(newContract);
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
        GitRepositoryI repo = GitRepositoryI(repositoryReg.getAddr(_projectId));
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
        GitRepositoryI repo = GitRepositoryI(repositoryReg.getAddr(_projectId));
        uint len = _userId.length;
        for (uint i = 0; i < len; i++) {
            address addr = userReg.getAddr(_userId[i]);
            repo.setBountyPoints(_issueId, addr, _points[i]);
        }
    }

    function newPoints(uint _repoId, uint[] _userIds, uint[] _points) public package {
        GitRepositoryI repo = GitRepositoryI(repositoryReg.getAddr(_repoId));
        uint len = _userIds.length;
        for (uint i = 0; i < len; i++) {
            uint _userId = _userIds[i];
            uint _uPoints = _points[i];
            address addr = userReg.getAddr(_userId);
            if (addr == 0x0 || !repo.claim(addr, _uPoints)) {
                pending[_userId][_repoId] += _uPoints;
            }
        }
    }

}