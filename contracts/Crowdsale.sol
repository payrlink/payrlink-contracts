// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IPAYR.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Crowdsale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

	/* if the funding goal is not reached, investors may withdraw their funds */
	uint256 public fundingGoal = 2000 * (10**18);
	/* the maximum amount of tokens to be sold */
	uint256 public maxGoal = 40000000 * (10**18);
	/* how much has been raised by crowdale (in ETH) */
	uint256 public amountRaised;
	/* how much has been raised by crowdale (in PAYR) */
	uint256 public amountRaisedPAYR;

	/* the start & end date of the crowdsale */
	uint256 public start;
	uint256 public deadline;

	/* there are different prices in different time intervals */
	uint256 public startPrice = 21000;
	uint256 public endPrice = 19000;

	/* the address of the token contract */
	IPAYR private tokenReward;
	/* the balances (in ETH) of all investors */
	mapping(address => uint256) public balanceOf;
	/* the balances (in PAYR) of all investors */
	mapping(address => uint256) public balanceOfPAYR;
	/* indicates if the crowdsale has been closed already */
	bool public crowdsaleClosed = false;
	/* notifying transfers and the success of the crowdsale*/
	event GoalReached(address beneficiary, uint256 amountRaised);
	event FundTransfer(address backer, uint256 amount, bool isContribution, uint256 amountRaised);

    /*  initialization, set the token address */
    constructor(IPAYR _token, uint256 _start, uint256 _dead) {
        tokenReward = _token;
		start = _start;
		deadline = _dead;
    }

    /* invest by sending ether to the contract. */
    receive () external payable {
		if(msg.sender != owner()) //do not trigger investment if the multisig wallet is returning the funds
        	invest();
		else revert();
    }

	function checkFunds(address addr) public view returns (uint256) {
		return balanceOf[addr];
	}

	function checkPAYRFunds(address addr) public view returns (uint256) {
		return balanceOfPAYR[addr];
	}

	function getETHBalance() public view returns (uint256) {
		return address(this).balance;
	}

	function getCurrentPrice() public view returns (uint256) {
		return startPrice - (startPrice - endPrice) * amountRaised / fundingGoal;
	}

    /* make an investment
    *  only callable if the crowdsale started and hasn't been closed already and the maxGoal wasn't reached yet.
    *  the current token price is looked up and the corresponding number of tokens is transfered to the receiver.
    *  the sent value is directly forwarded to a safe multisig wallet.
    *  this method allows to purchase tokens in behalf of another address.*/
    function invest() public payable {
    	uint256 amount = msg.value;
		require(crowdsaleClosed == false && block.timestamp >= start && block.timestamp < deadline, "Crowdsale is closed");
		require(msg.value >= 5 * 10**17, "Fund is less than 0.5 ETH");
		require(msg.value <= 20 * 10**18, "Fund is more than 20 ETH");

		balanceOf[msg.sender] = balanceOf[msg.sender].add(amount);
		amountRaised = amountRaised.add(amount);

		uint256 price = this.getCurrentPrice();
		balanceOfPAYR[msg.sender] = balanceOfPAYR[msg.sender].add(amount.mul(price));
		amountRaisedPAYR = amountRaisedPAYR.add(amount.mul(price));

		if (amountRaisedPAYR >= maxGoal) {
			crowdsaleClosed = true;
			emit GoalReached(msg.sender, amountRaised);
		}
		
        emit FundTransfer(msg.sender, amount, true, amountRaised);
    }

    modifier afterClosed() {
        require(block.timestamp >= deadline || crowdsaleClosed == true, "Distribution is off.");
        _;
    }

	function getPAYR() public afterClosed nonReentrant {
		require(balanceOfPAYR[msg.sender] > 0, "Zero ETH contributed.");
		uint256 amount = balanceOfPAYR[msg.sender];
		balanceOfPAYR[msg.sender] = 0;
		tokenReward.transfer(msg.sender, amount);
	}

	function withdrawETH() public onlyOwner afterClosed {
		uint256 balance = this.getETHBalance();
		require(balance > 0, "Balance is zero.");
		address payable payableOwner = payable(owner());
		payableOwner.transfer(balance);
	}

	function withdrawPAYR() public onlyOwner afterClosed{
		uint256 balance = tokenReward.balanceOf(address(this));
		require(balance > 0, "Balance is zero.");
		tokenReward.transfer(owner(), balance);
	}
}