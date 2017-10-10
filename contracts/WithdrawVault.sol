pragma solidity ^0.4.11;

import "../zeppelin/contracts/math/SafeMath.sol";
import "../zeppelin/contracts/ownership/Ownable.sol";

/**
 * @title RefundVault
 * @dev This contract is used for storing funds while a crowdsale
 * is in progress. Supports refunding the money if crowdsale fails,
 * and forwarding it if crowdsale is successful.
 */
contract WithdrawVault is Ownable {
    using SafeMath for uint256;

    mapping (address => uint256) public deposited;
    address public wallet;


    function WithdrawVault(address _wallet) {
        require(_wallet != 0x0);
        wallet = _wallet;
    }

    function deposit(address investor) onlyOwner payable {
        deposited[investor] = deposited[investor].add(msg.value);
    }

    function close() onlyOwner {
        wallet.transfer(this.balance);
    }

}
