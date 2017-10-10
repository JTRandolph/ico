
var PundiXToken = artifacts.require('./PundiXToken.sol');
var PundiXPreICO = artifacts.require('./PundiXPreICO.sol');

module.exports = function(deployer, network, accounts) {

    let beginTime = 1507341600;         // 2017.10.07   10:00:00
    let endTime = 1509156000;           // 2017.10.28   10:00:00
    let rate = 500;
    let wallet = "0x";

    // pre
    var limit = web3.toWei(14000, 'ether');
    deployer.deploy(PundiXToken)
    .then(() => deployer.deploy(PundiXPreICO, beginTime, endTime, wallet, limit))
    .then(() => PundiXPreICO.deployed())
    .then(crowdsale => crowdsale.setToken(PundiXToken.address))
    .then(() => PundiXToken.deployed())
    .then(token => token.transferOwnership(PundiXPreICO.address));

};
