pragma solidity ^0.4.11;
import "../zeppelin/contracts/token/MintableToken.sol";
import "../zeppelin/contracts/token/BurnableToken.sol";
import '../zeppelin/contracts/math/SafeMath.sol';

contract PundiXToken is MintableToken, BurnableToken {

    event ShowCurrentIndex(address indexed to, uint256 value);
    event ShowBonus(address indexed to, uint256 value);

    string public constant name = "Pundi X Token";
    string public constant symbol = "PXS";
    uint8 public constant decimals = 18;

    uint256 public totalSupplyBonus;

    // TODO 权益时间
    // TODO 权益时间
    uint64[] public bonusTimeList = [
    1512057600,1514736000,1517414400,1519833600,1522512000,1525104000,1527782400,1530374400,1533052800,1535731200,1538323200,1541001600,
    1543593600,1546272000,1548950400,1551369600,1554048000,1556640000,1559318400,1561910400,1564588800,1567267200,1569859200,1572537600,
    1575129600,1577808000,1580486400,1582992000,1585670400,1588262400,1590940800,1593532800,1596211200,1598889600,1601481600,1604160000];


    uint8 public currentTimeIndex;

    function PundiXToken() {
        currentTimeIndex = 0;
    }

    // --------------------------------------------------------
    mapping(address=>uint256) weiBalance;
    address[] public investors;

    function addWei(address _address, uint256 _value) onlyOwner canMint public {
        uint256 value = weiBalance[_address];
        if (value == 0) {
            investors.push(_address);
        }
        weiBalance[_address] = value.add(_value);
    }

    function getInvestorsCount() constant onlyOwner public returns (uint256 investorsCount) {
        return investors.length;
    }

    function getWeiBalance(address _address) constant onlyOwner public returns (uint256 balance) {
        return weiBalance[_address];
    }

    // --------------------------------------------------------


    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        bool result = super.transferFrom(_from, _to, _value);
        if (result && currentTimeIndex < bonusTimeList.length) {
            bonus(_from);
            bonus(_to);
        }
        return result;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        bool result = super.transfer(_to, _value);
        if (result && currentTimeIndex < bonusTimeList.length) {
            bonus(msg.sender);
            bonus(_to);
        }
        return result;
    }


    function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
        bool result = super.mint(_to, _amount);
        if (result) {
            bonus(_to);
        }
        return result;
    }

    function burn(uint256 _value) public {
        super.burn(_value);
        if (currentTimeIndex < bonusTimeList.length) {
            bonus(msg.sender);
        }

    }
    // --------------------------------------------------------

    mapping(address => User) public users;

    struct User {
        uint256 txTimestamp;
        uint256[] monthBalance;
        uint8 monthIndex;
        uint256[] receiveBonus;
        uint8 receiveIndex;
    }

    function bonus(address _address) internal {
        User storage user = users[_address];
        tryNextTimeRange();

        uint64 maxTime = bonusTimeList[currentTimeIndex];
        if (user.txTimestamp > maxTime) {
            return;
        }

        uint64 minTime = 0;
        if (currentTimeIndex > 0) {
            minTime = bonusTimeList[currentTimeIndex-1];
        }

        for (uint _i = user.monthBalance.length; _i <= currentTimeIndex; _i++) {
            user.monthBalance.push(0);
        }

        // first time
        if (user.txTimestamp == 0) {
            user.monthBalance[currentTimeIndex] = balances[_address];
            user.monthIndex = currentTimeIndex;
        } else if (user.txTimestamp >= minTime) {
            user.monthBalance[currentTimeIndex] = balances[_address];
        } else { // (user.txTimestamp < minTime) cross month
            uint256 pBalance = user.monthBalance[user.monthIndex];
            for (uint8 i = user.monthIndex; i < currentTimeIndex; i++) {
                user.monthBalance[i] = pBalance;
            }
            user.monthBalance[currentTimeIndex] = balances[_address];
            user.monthIndex = currentTimeIndex;
        }
        user.txTimestamp = now;

    }

    function tryNextTimeRange() internal {
        uint8 len = uint8(bonusTimeList.length) - 1;
        uint64 _now = uint64(now);
        for(; currentTimeIndex < len; currentTimeIndex++) {
            if (bonusTimeList[currentTimeIndex] >= _now) {
                break;
            }
        }
    }

    function receiveBonus() public {
        tryNextTimeRange();

        if (currentTimeIndex == 0) {
            return;
        }

        address addr = msg.sender;

        User storage user = users[addr];

        if (user.monthIndex < currentTimeIndex) {
            bonus(addr);
        }

        User storage xuser = users[addr];

        if (xuser.receiveIndex == xuser.monthIndex || xuser.receiveIndex >= bonusTimeList.length) {
            return;
        }


        require(user.receiveIndex < user.monthIndex);

        uint8 monthInterval = xuser.monthIndex - xuser.receiveIndex;

        uint256 bonusToken = 0;

        if (monthInterval > 6) {
            uint8 _length = monthInterval - 6;

            for (uint8 j = 0; j < _length; j++) {
                xuser.receiveBonus.push(0);
                xuser.receiveIndex++;
            }
        }

        uint256 balance = xuser.monthBalance[xuser.monthIndex];

        for (uint8 i = xuser.receiveIndex; i < xuser.monthIndex; i++) {
            uint256 preMonthBonus = calculateBonusToken(i, balance);
            balance = preMonthBonus.add(balance);
            bonusToken = bonusToken.add(preMonthBonus);
            xuser.receiveBonus.push(preMonthBonus);
            xuser.receiveIndex++;
        }

        // 事件
        ShowBonus(addr, bonusToken);

        if (bonusToken == 0) {
            return;
        }

        totalSupplyBonus = totalSupplyBonus.sub(bonusToken);

        this.transfer(addr, bonusToken);
    }

    function calculateBonusToken(uint8 _monthIndex, uint256 _balance) internal returns (uint256) {
        uint256 bonusToken = 0;
        if (_monthIndex < 12) {
            // 7.31606308769453%
            bonusToken = _balance.div(10000000000000000).mul(731606308769453);
        } else if (_monthIndex < 24) {
            // 2.11637098909784%
            bonusToken = _balance.div(10000000000000000).mul(211637098909784);
        } else if (_monthIndex < 36) {
            // 0.881870060450728%
            bonusToken = _balance.div(100000000000000000).mul(881870060450728);
        }

        return bonusToken;
    }


    function calculationTotalSupply() onlyOwner {
        uint256 u1 = totalSupply.div(10);

        uint256 year1 = u1.mul(4);
        uint256 year2 = u1.mul(2);
        uint256 year3 = u1;

        totalSupplyBonus = year1.add(year2).add(year3);
    }

    function recycleUnreceivedBonus(address _address) onlyOwner {
        tryNextTimeRange();
        require(currentTimeIndex > 34);

        uint64 _now = uint64(now);

        uint64 maxTime = bonusTimeList[currentTimeIndex];

        uint256 bonusToken = 0;

        // TODO 180 days
        uint64 finalTime = 180 days + maxTime;

        if (_now > finalTime) {
            bonusToken = totalSupplyBonus;
            totalSupplyBonus = 0;
        }

        require(bonusToken != 0);

        this.transfer(_address, bonusToken);
    }

}