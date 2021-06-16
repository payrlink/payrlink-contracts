// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IPayrLink.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ETHFactory is Ownable {
    string public name;         // Factory Name

    struct TransactionInfo {
        uint256 id;             // Transaction ID
        address from;           // Address Which has sent
        bytes32 toHash;          // Hash of recipient's Address
        uint256 amount;         // Transaction amount
        uint256 timestamp;      // Transaction time
        uint8 pending;           // Released or pending - 0: pending, 1: available, 2: finished, 3: Canceled
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
        @param _name Factory name
        @param _payrlink Interface of PayrLink
     */
    constructor(string memory _name, IPayrLink _payrlink) {
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

    function pendingToIds(bytes32 _to) external view returns (uint256[] memory) {
        return pendingTo[_to];
    }

    function updateFeePercent(uint256 _feePercent) external onlyOwner {
        feePercent = _feePercent;
    }

    /**
        @notice Deposit ETH to the contract
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
        @notice Update pool id of PayrLink
        @param _pid New pool id
     */
    function updatePoolId (uint256 _pid) external onlyOwner {
        poolId = _pid;
    }

    /**
        @notice Withdraw ETH from the contract
        @param amount ETH amount to withdraw
     */
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Withdraw amount exceed");
        address payable receipient = payable(msg.sender);
        balances[msg.sender] -= amount;
        receipient.transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    /**
        @notice Send ETH to a receipient's address(hashed) via Escrow service
        @param _toHash Hash of the receipient's address
        @param _amount ETH amount to send
     */
    function send(bytes32 _toHash, uint256 _amount) external {
        require(balances[msg.sender] >= _amount, "Withdraw amount exceed");
        balances[msg.sender] -= _amount;

        transactions.push(TransactionInfo(currentId, msg.sender, _toHash, _amount, block.timestamp, 0));
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
        require(transactions[_id].from == msg.sender && transactions[_id].pending < 1, "Invalid owner");
        transactions[_id].pending = 1;
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
        require(transactions[_id].pending == 1, "Funds are not released");

        transactions[_id].pending = 2;

        removeFromPending(_id);

        uint256 fee = transactions[_id].amount * feePercent / 10000;
        payable(address(payrLink)).transfer(fee);
        payrLink.addReward(poolId, fee);

        balances[msg.sender] += transactions[_id].amount - fee;

        emit GetFund(transactions[_id].from, transactions[_id].amount, transactions[_id].timestamp);
    }

    function cancel(uint256 _id) external {
        bytes32 toHash = keccak256(abi.encodePacked(msg.sender));

        require(transactions[_id].toHash == toHash, "Invalid receipient");
        require(transactions[_id].pending == 0, "Funds are not pending");

        transactions[_id].pending = 3;      // canceled

        removeFromPending(_id);

        balances[transactions[_id].from] += transactions[_id].amount;

        emit CancelTransaction(transactions[_id].from, transactions[_id].amount, transactions[_id].timestamp);
    }

}