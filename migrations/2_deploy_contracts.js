var strings = artifacts.require("./helpers/strings.sol");
var GitFactory = artifacts.require("./GitRepository.sol");
var GHUserReg = artifacts.require("./GHUserReg.sol");
var GHRepoReg = artifacts.require("./GHRepoReg.sol");
var GHPoints = artifacts.require("./GHPoints.sol");
var GitHubOracle = artifacts.require("./GitHubOracle.sol");

module.exports = function(deployer) {
  deployer.deploy(strings);
  deployer.link(strings, [GHUserReg, GHRepoReg, GHPoints]);
  deployer.deploy([[GHUserReg], [GHRepoReg], [GHPoints]]);
  deployer.link(GHUserReg, GitHubOracle);
  deployer.link(GHRepoReg, GitHubOracle);
  deployer.link(GHPoints, GitHubOracle);
  deployer.deploy(GitHubOracle);
};
