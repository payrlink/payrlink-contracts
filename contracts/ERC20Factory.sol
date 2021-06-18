// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IPayrLink.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Factory is Ownable {
    IERC20 private token;               // ERC20 Token
    string public name;         // Factory Name

    struct TransactionInfo {
        uint256 id;             // Transaction ID
        uint256 amount;         // Transaction amount
        uint256 timestamp;      // Transaction time
        uint256 status;           // Released or pending - 0: pending, 1: available, 2: finished, 3: canceled
        address from;           // Address Which has sent
        bytes32 toHash;          // Hash of recipient's Address
        string description;     // Description
    }

    TransactionInfo[] public transactions;
    uint256 public currentId;

    mapping (address => uint256) private balances;              // Available balance which can be withdrawn
    mapping (address => uint256[]) private pendingFrom;         // Transaction IDs in escrow service from sender's address
    mapping (bytes32 => uint256[]) private pendingTo;            // Transaction IDs in escrow service to receipent's hash

    uint256 public poolId;                      // Pool id on PayrLink
    IPayrLink payrLink;
    uint256 public feePercent = 80;                         // 1 = 0.01 %

    event SendTransaction(address from, uint256 amount, uint256 timestamp);
    event ReleaseFund(address from, uint256 amount, uint256 timestamp);
    event GetFund(address from, uint256 amount, uint256 timestamp);
    event CancelTransaction(address from, uint256 amount, uint256 timestamp);
    event Deposit(address from, uint256 amount);
    event Withdraw(address to, uint256 amount);

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
        @notice Get balance of sender
     */
    function balanceOf() external view returns(uint256) {
        return balances[msg.sender];
    }

    function pendingFromIds() external view returns (uint256[] memory) {
        return pendingFrom[msg.sender];
    }

    function pendingToIds() external view returns (uint256[] memory) {
        bytes32 toHash = keccak256(abi.encodePacked(msg.sender));
        return pendingTo[toHash];
    }

    function updateFeePercent(uint256 _feePercent) external onlyOwner {
        feePercent = _feePercent;
    }

    /**
        @notice Deposit ERC20 token to the contract
        @param amount ERC20 token amount to deposit
     */
    function deposit(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
        @notice Update pool id of PayrLink
        @param _pid New pool id
     */
    function updatePoolId (uint256 _pid) external onlyOwner {
        poolId = _pid;
    }

    /**
        @notice Withdraw ERC20 token from the contract
        @param amount ERC20 token amount to withdraw
     */
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Withdraw amount exceed");
        balances[msg.sender] -= amount;
        token.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /**
        @notice Send ERC20 token to a receipient's address(hashed) via Escrow service
        @param _toHash Hash of the receipient's address
        @param _amount ERC20 token amount to send
     */
    function send(bytes32 _toHash, uint256 _amount, string memory _desc) external {
        require(balances[msg.sender] >= _amount, "Withdraw amount exceed");
        balances[msg.sender] -= _amount;

        transactions.push(TransactionInfo(currentId, _amount, block.timestamp, 0, msg.sender, _toHash, _desc));
        pendingFrom[msg.sender].push(currentId);
        pendingTo[_toHash].push(currentId);

        currentId ++;
        emit SendTransaction(msg.sender, _amount, block.timestamp);
    }

    /**
        @notice Release the fund of an Escrow transaction, will be called by sender
        @param _id Transaction ID
     */
    function release(uint256 _id) external {
        require(transactions[_id].from == msg.sender && transactions[_id].status < 1, "Invalid owner");
        transactions[_id].status = 1;
        emit ReleaseFund(transactions[_id].from, transactions[_id].amount, transactions[_id].timestamp);
    }

    function removeFromPending(uint256 _id) internal {
        address sender = transactions[_id].from;
        bytes32 toHash = transactions[_id].toHash;
        // Remove transaction id from pendingFrom array
        uint256 pendingLen = pendingFrom[sender].length;
        for (uint256 i = 0 ; i < pendingLen ; i ++) {
            if (pendingFrom[sender][i] == _id) {
                pendingFrom[sender][i] = pendingFrom[sender][pendingLen - 1];
                pendingFrom[sender].pop();
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
    }

    /**
        @notice Get the fund which has been available in Escrow, will be called by receipient
        @param _id Transaction ID
     */
    function getFund(uint256 _id) external {
        bytes32 toHash = keccak256(abi.encodePacked(msg.sender));

        require(transactions[_id].toHash == toHash, "Invalid receipient");
        require(transactions[_id].status == 1, "Funds are not released");

        transactions[_id].status = 2;

        removeFromPending(_id);

        uint256 fee = transactions[_id].amount * feePercent / 10000;
        token.transfer(address(payrLink), fee);
        payrLink.addReward(poolId, fee);

        balances[msg.sender] += transactions[_id].amount - fee;
        emit GetFund(transactions[_id].from, transactions[_id].amount, transactions[_id].timestamp);
    }

    /**
        @notice Get the fund which has been available in Escrow, will be called by receipient
        @param _id Transaction ID
     */
    function cancel(uint256 _id) external {
        bytes32 toHash = keccak256(abi.encodePacked(msg.sender));

        require(transactions[_id].toHash == toHash, "Invalid receipient");
        require(transactions[_id].status == 0, "Funds are not pending");

        transactions[_id].status = 3;      // canceled

        removeFromPending(_id);

        balances[transactions[_id].from] += transactions[_id].amount;
        emit CancelTransaction(transactions[_id].from, transactions[_id].amount, transactions[_id].timestamp);
    }

}