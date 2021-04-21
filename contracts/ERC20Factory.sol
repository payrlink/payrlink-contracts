// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IPayrLink.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Factory is Ownable {
    IERC20 private token;               // ERC20 Token
    string public name;         // Factory Name

    struct TransactionInfo {
        uint256 id;             // Transaction ID
        address from;           // Address Which has sent
        bytes32 toHash;          // Hash of recipient's Address
        uint256 amount;         // Transaction amount
        uint256 timestamp;      // Transaction time
        uint8 pending;           // Released or pending - 0: pending, 1: available, 2: finished
    }

    TransactionInfo[] private transactions;
    uint256 public currentId;

    mapping (address => uint256) private balances;              // Available balance which can be withdrawn
    mapping (address => uint256[]) private pendingFrom;         // Transaction IDs in escrow service from sender's address
    mapping (bytes32 => uint256[]) private pendingTo;            // Transaction IDs in escrow service to receipent's hash

    uint256 public poolId;                      // Pool id on PayrLink
    IPayrLink payrLink;

    /**
        @notice Initialize ERC20 token and Factory name
        @param _token ERC20 token
        @param _name Factory name
        @param _payrlink Interface of PayrLink
     */
    constructor(IERC20 _token, string memory _name, IPayrLink _payrlink) {
        token = _token;
        name = _name;
        payrLink = _payrlink;
    }

    /**
        @notice Deposit ERC20 token to the contract
        @param amount ERC20 token amount to deposit
     */
    function deposit(uint256 amount) public {
        token.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }

    /**
        @notice Update pool id of PayrLink
        @param _pid New pool id
     */
    function updatePoolId (uint256 _pid) public onlyOwner {
        poolId = _pid;
    }

    /**
        @notice Withdraw ERC20 token from the contract
        @param amount ERC20 token amount to withdraw
     */
    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Withdraw amount exceed");
        token.transfer(msg.sender, amount);
        balances[msg.sender] -= amount;
    }

    /**
        @notice Send ERC20 token to a receipient's address(hashed) via Escrow service
        @param _toHash Hash of the receipient's address
        @param _amount ERC20 token amount to send
     */
    function send(bytes32 _toHash, uint256 _amount) public {
        require(balances[msg.sender] >= _amount, "Withdraw amount exceed");
        balances[msg.sender] -= _amount;

        transactions.push(TransactionInfo(currentId, msg.sender, _toHash, _amount, block.timestamp, 0));
        pendingFrom[msg.sender].push(currentId);
        pendingTo[_toHash].push(currentId);

        currentId ++;
    }

    /**
        @notice Release the fund of an Escrow transaction, will be called by sender
        @param _id Transaction ID
     */
    function release(uint256 _id) public {
        require(transactions[_id].from == msg.sender, "Invalid owner");
        transactions[_id].pending = 1;
    }

    /**
        @notice Get the fund which has been available in Escrow, will be called by receipient
        @param _id Transaction ID
     */
    function getFund(uint256 _id) public {
        bytes32 toHash = keccak256(abi.encodePacked(msg.sender));

        require(transactions[_id].toHash == toHash, "Invalid receipient");
        require(transactions[_id].pending == 1, "Funds are not released");

        transactions[_id].pending = 2;

        // Remove transaction id from pendingFrom array
        uint256 pendingLen = pendingFrom[msg.sender].length;
        for (uint256 i = 0 ; i < pendingLen ; i ++) {
            if (pendingFrom[msg.sender][i] == _id) {
                pendingFrom[msg.sender][i] = pendingFrom[msg.sender][pendingLen - 1];
                pendingFrom[msg.sender].pop();
                break;
            }
        }

        // Remove transaction id from pendingTo array
        pendingLen = pendingTo[toHash].length;
        for (uint256 i = 0 ; i < pendingLen ; i ++) {
            if (pendingTo[toHash][i] == _id) {
                pendingTo[toHash][i] = pendingTo[toHash][pendingLen - 1];
                pendingTo[toHash].pop();
                break;
            }
        }

        uint256 fee = transactions[_id].amount * 8 / 1000;
        token.transfer(address(payrLink), fee);
        payrLink.addReward(poolId, fee);

        balances[msg.sender] += transactions[_id].amount - fee;
    }
}