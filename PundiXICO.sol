pragma solidity ^0.4.11;
import "../zeppelin/contracts/token/MintableToken.sol";
import "../zeppelin/contracts/crowdsale/FinalizableCrowdsale.sol";
import "../zeppelin/contracts/crowdsale/RefundVault.sol";
import "./PundiXToken.sol";

contract PundiXICO is FinalizableCrowdsale {

    event BuyTheToken(address indexed to, uint256 amount);

    uint256 public weiLimit;

    address public management;
    address public company;
    address public consultant;

    address public tokenAddress;

    uint8 public receiveBonusCount = 0;

    bool public isRefund;

    uint256 public tokenAmount;

    address wallet;


    PundiXToken xToken;

    RefundVault public vault;


    function PundiXICO(uint256 _startTime, uint256 _endTime, uint256 _rate, uint256 _weiLimit, address _wallet,
    address _management, address _company, address _consultant
    )
    FinalizableCrowdsale()
    Crowdsale(_startTime, _endTime, _rate, _wallet)
    {
        require(_management != 0x0);
        require(_company != 0x0);
        require(_consultant != 0x0);
        require(_weiLimit > 0);

        weiLimit = _weiLimit;

        wallet = _wallet;

        management = _management;
        company = _company;
        consultant = _consultant;

        isRefund = false;
        vault = new RefundVault(wallet);

    }

    // TODO 30 days
    // 锁定时间间隔
    uint64 public grantInterval = 30 days;
    // 锁定代币记录
    mapping(address => TokenGrant) public grants;

    struct TokenGrant {
        uint256 value;
        uint64 start;
        uint8 period;
    }

    function revokeTokenGrant() public {
        require(hasEnded());
        require(isFinalized);

        address _address = msg.sender;

        TokenGrant storage grant = grants[_address];
        require(grant.start < now);
        require(grant.value > 0);
        require(grant.period > 0);

        uint256 value = grant.value.div(grant.period);
        grant.value = grant.value.sub(value);
        grant.period--;

        grant.start += grantInterval;

        xToken.transfer(_address, value);
    }


    function finalization() internal {
        uint256 supply = token.totalSupply();

        tokenAmount = supply;

        grantVestedTokens(management, supply, 10, 25);
        grantVestedTokens(company, supply, 10, 20);
        grantVestedTokens(consultant, supply, 10, 5);

        // 需要生成剩下的70%
        uint256 remainSupply = supply.div(2).mul(7);
        token.mint(tokenAddress, remainSupply);

        // 计算每年token权益总量
        xToken.calculationTotalSupply();

        vault.close();

        super.finalization();
    }

    function grantVestedTokens(address _to, uint256 _value, uint8 _period, uint _proportion) internal {
        uint256 value = _value.div(100).mul(_proportion);
        grants[_to] = TokenGrant(value, uint64(now.add(grantInterval)), _period);
        token.mint(this, value);
    }


    function createTokenContract() internal returns (MintableToken) {
        return token;
    }


    // set external token
    function setToken(address _mintToken) onlyOwner {
        xToken = PundiXToken(_mintToken);
        token = xToken;
        tokenAddress = _mintToken;
    }

    // update token owner
    function transferTokenOwner(address _newOwner) onlyOwner {
        token.transferOwnership(_newOwner);
    }

    // low level token purchase function
    function buyTokens(address beneficiary) payable {
        require(beneficiary != 0x0);
        require(validPurchase());
        require(!isRefund);

        uint256 weiAmount = msg.value;

        require(weiAmount > 0 ether);

        uint256 tokens = weiAmount.mul(rate);


        BuyTheToken(beneficiary, tokens);

        // update state
        weiRaised = weiRaised.add(weiAmount);

        token.mint(beneficiary, tokens);
        TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

        xToken.addWei(msg.sender, msg.value);

        forwardFunds();

    }

    // @return true if crowdsale event has ended
    function hasEnded() public constant returns (bool) {
        if (super.hasEnded()) {
            return true;
        }
        // 众筹达到上限也停止
        return weiRaised >= weiLimit;
    }

    function getWeiBalance(address _address) constant onlyOwner returns (uint256 balance) {
        return xToken.getWeiBalance(_address);
    }


    function grantReceiveBonus() onlyOwner returns (bool) {
        require(receiveBonusCount <= 10);
        receiveBonusCount++;

        TokenGrant storage managementGrant = grants[management];
        TokenGrant storage companyGrant = grants[company];
        TokenGrant storage consultantGrant = grants[consultant];

        uint256 grantTotalTokens = xToken.balanceOf(this);

        // 领取权益
        xToken.receiveBonus();

        uint256 newGrantTotalTokens = xToken.balanceOf(this);

        uint256 grantBonus = newGrantTotalTokens - grantTotalTokens;

        if (10 - managementGrant.period < receiveBonusCount) {
            managementGrant.value = managementGrant.value.div(grantTotalTokens).mul(grantBonus).add(managementGrant.value);
        }

        if (10 - companyGrant.period < receiveBonusCount) {
            companyGrant.value = companyGrant.value.div(grantTotalTokens).mul(grantBonus).add(companyGrant.value);
        }

        if (10 - consultantGrant.period < receiveBonusCount) {
            consultantGrant.value = consultantGrant.value.div(grantTotalTokens).mul(grantBonus).add(consultantGrant.value);
        }

        return true;
    }

    function forwardFunds() internal {
        vault.deposit.value(msg.value)(msg.sender);
    }

    function refund() onlyOwner {
        require(!isFinalized);
        isRefund = true;
        vault.enableRefunds();
    }

    function claimRefund() {
        require(isRefund);
        vault.refund(msg.sender);
    }

    function recycleUnreceivedTokenBonus() onlyOwner {
        xToken.recycleUnreceivedBonus(wallet);

        uint256 grantUnreceivedTokens = xToken.balanceOf(this);
        xToken.transfer(wallet, grantUnreceivedTokens);
    }

}
