// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IPAYR.sol";
import "./interfaces/IPayrLink.sol";
import "./interfaces/IFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PayrLink is Ownable, IPayrLink, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Address of the PAYR Token contract.
    IPAYR public payrToken;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes PAYR.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    constructor(IPAYR _payr) {
        payrToken = _payr;
    }

    // Number of pools
    function poolLength() external view override returns (uint256) {
        return poolInfo.length;
    }

    // Add a new ERC20 token pool. Can only be called by the owner.
    function addPool(IFactory _factory, bool _withUpdate) external onlyOwner returns (uint256 _id) {
        if (_withUpdate) {
            massUpdatePools();
        }
        _id = poolInfo.length;
        poolInfo.push(PoolInfo({
            totalReward: 0,
            accERC20PerShare: 0,
            totalDeposited: 0,
            revenue: 0,
            factory: _factory
        }));
    }

    // Add rewards to the pool from factory
    function addReward (uint256 _pid, uint256 _amount) external override {
        PoolInfo storage pool = poolInfo[_pid];
        require(msg.sender == address(pool.factory), "Invalid Factory");
        pool.totalReward += _amount;
        pool.revenue += _amount;
    }

    // View function to see deposited token for a user.
    function deposited(uint256 _pid, address _user) external view override returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        return user.amount;
    }

    // View function to see pending rewards for a user.
    function pending(uint256 _pid, address _user) external view override returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accERC20PerShare = pool.accERC20PerShare;
        uint256 payrSupply = pool.totalDeposited;
        uint256 erc20Reward = pool.totalReward;

        if (payrSupply != 0) {
            accERC20PerShare = accERC20PerShare.add(erc20Reward.mul(1e36).div(payrSupply));
        }

        return user.amount.mul(accERC20PerShare).div(1e36).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public override {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 payrSupply = pool.totalDeposited;
        if (payrSupply == 0) {
            return;
        }

        uint256 erc20Reward = pool.totalReward;

        pool.accERC20PerShare = pool.accERC20PerShare.add(erc20Reward.mul(1e36).div(payrSupply));
        pool.totalReward = 0;
    }

    // Deposit PAYR to pool for ERC20 allocation.
    function deposit(uint256 _pid, uint256 _amount) external override nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pendingAmount = user.amount.mul(pool.accERC20PerShare).div(1e36).sub(user.rewardDebt);
            pool.factory.harvestFee(msg.sender, pendingAmount);
        }
        payrToken.transferFrom(address(msg.sender), address(this), _amount);
        pool.totalDeposited += _amount;
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accERC20PerShare).div(1e36);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw PAYR tokens from Farm.
    function withdraw(uint256 _pid, uint256 _amount) external override nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount && pool.totalDeposited >= _amount, "withdraw: can't withdraw more than deposit");
        updatePool(_pid);
        uint256 pendingAmount = user.amount.mul(pool.accERC20PerShare).div(1e36).sub(user.rewardDebt);
        pool.factory.harvestFee(msg.sender, pendingAmount);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accERC20PerShare).div(1e36);
        payrToken.transfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
        pool.totalDeposited -= _amount;
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external override {
        UserInfo storage user = userInfo[_pid][msg.sender];
        payrToken.transfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }
}
