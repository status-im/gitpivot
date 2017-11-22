/**
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH) 
 */
contract IGitPivot {

    /**
     * 
     */
    function setHead(uint256 projectId, string head) public;

    /**
     * 
     */
    function setTail(uint256 projectId, string tail) public;

    /**
     * 
     */
    function newPoints(uint256 projectId, uint256[] userIds, uint[] totals) public;

    /**
     * 
     */
    function pendingScan(uint256 projectId, string lastCommit, string pendingTail) public;

    /**
     * 
     */
    function setIssue(
        uint256 projectId,
        uint256 issueId,
        bool state,
        uint256 closedAt) public;

    /**
     * 
     */
    function setIssuePoints(
        uint256 projectId, 
        uint256 issueId,
        uint256[] userIds, 
        uint256[] points) public;

}