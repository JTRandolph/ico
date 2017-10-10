pragma solidity ^0.4.11;

import "../zeppelin/contracts/crowdsale/CappedCrowdsale.sol";
import "../zeppelin/contracts/ownership/Ownable.sol";
import "../zeppelin/contracts/token/MintableToken.sol";
import "../zeppelin/contracts/crowdsale/RefundVault.sol";
import "./PundiXToken.sol";
import "./WithdrawVault.sol";



contract PundiXPreICO is CappedCrowdsale, Ownable {

    uint256 public mintTokenCount;

    PundiXToken xToken;

    uint256 public totalBalance;

    WithdrawVault public withdrawVault;

    function PundiXPreICO(uint256 _startTime, uint256 _endTime, address _wallet, uint256 _tokenLimit)
    CappedCrowdsale(_tokenLimit)
    Crowdsale( _startTime, _endTime,  500, _wallet)
    {
        withdrawVault = new WithdrawVault(_wallet);
    }

    function createTokenContract() internal returns (MintableToken) {
        return token;
    }

    // set external token
    function setToken(address _mintToken) onlyOwner {
        xToken = PundiXToken(_mintToken);
        token = xToken;
    }

    // update token owner
    function transferTokenOwner(address _newOwner) onlyOwner {
        token.transferOwnership(_newOwner);
    }

    function setEndTime(uint256 _endTime) onlyOwner {
        endTime = _endTime;
    }

    function buyTokens(address beneficiary) public payable {
        require(beneficiary != 0x0);
        require(validPurchase());

        uint256 weiAmount = msg.value;

        require(weiAmount > 0 ether);
        //require(weiAmount >= 1 ether);

        xToken.addWei(msg.sender, weiAmount);

        // calculate token amount to be created
        // 70% sale
        uint256 tokens = weiAmount.mul(500);
        uint256 reward = tokens.mul(3).div(10);

        //TODO 赠送
        //TODO 赠送
        if (weiAmount >= 3000 ether) {
            reward = reward.add(tokens.mul(55).div(100));
        } else if (weiAmount >= 1000 ether) {
            reward = reward.add(tokens.mul(40).div(100));
        } else if (weiAmount >= 500 ether) {
            reward = reward.add(tokens.mul(30).div(100));
        } else if (weiAmount >= 300 ether) {
            reward = reward.add(tokens.mul(20).div(100));
        } else if (weiAmount >= 100 ether) {
            reward = reward.add(tokens.mul(10).div(100));
        }


        uint256 allTokens = tokens.add(reward);

        mintTokenCount.add(allTokens);

        // update state
        weiRaised = weiRaised.add(weiAmount);

        token.mint(beneficiary, allTokens);
        TokenPurchase(msg.sender, beneficiary, weiAmount, allTokens);

        forwardFunds();
    }

    function getWeiBalance(address _address) constant onlyOwner returns (uint256 balance) {
        return xToken.getWeiBalance(_address);
    }

    function forwardFunds() internal {
        withdrawVault.deposit.value(msg.value)(msg.sender);
    }

    function withdraw() onlyOwner {
        withdrawVault.close();
    }

    function validPurchase() internal constant returns (bool) {
        bool withinCap = weiRaised <= cap;

        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        return withinPeriod && nonZeroPurchase && withinCap;
    }
}
