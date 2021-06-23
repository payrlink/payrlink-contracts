// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFactory {
    struct TransactionInfo {
        uint256 id;             // Transaction ID
        uint256 amount;         // Transaction amount
        uint256 createdAt;      // created time of transaction
        uint256 endedAt;        // released or canceled time of transaction
        uint256 status;           // Released or pending - 0: pending, 1: available, 2: finished, 3: Canceled
        address from;           // Address Which has sent
        bytes32 toHash;          // Hash of recipient's Address
        string description;     // Description
    }

    function harvestFee(address _to, uint256 _pending) external;
}
