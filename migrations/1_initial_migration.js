var Migrations = artifacts.require("./Migrations.sol");

module.exports = function(deployer) {
    // uint256 _startTime, uint256 _endTime, uint256 _rate, uint256 _goal, address _wallet
  // deployer.deploy(Test, 1504855690820, 1504855690820 + (30 * 24 * 60 * 60), 1000, 1000000 * 1000, 0x0);
  deployer.deploy(Migrations);
};
