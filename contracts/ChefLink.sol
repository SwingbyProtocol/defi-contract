// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPancakeswapFarm.sol";

contract ChefLink is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardCoinsDept;
        //
        // We do some fancy math here. Basically, any point in time, the amount of SWINGBYs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSwingbyPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accSwingbyPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. SWINGBYs to distribute per block.
        uint256 lastRewardBlock; // Last block number that SWINGBYs distribution occurs.
        uint256 accSwingbyPerShare; // Accumulated SWINGBYs per share, times 1e12. See below.
    }
    // The SWINGBY TOKEN!
    IERC20 public swingby;
    // Block number when bonus SWINGBY period ends.
    uint256 public bonusEndBlock;
    // SWINGBY tokens created per block.
    uint256 public swingbyPerBlock;
    // Bonus muliplier for early swingby makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Farming contract
    address public farmContract;
    // PID num of farming contract.
    uint256 public ppid;
    // Farming coin.
    address public farmCoin;
    // Total earned of farming coin
    uint256 public toalEarned;
    // Total locked farm LPT on farming contract.
    uint256 public totalLockedLPT;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when SWINGBY mining starts.
    uint256 public startBlock;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    function init(
        IERC20 _swingby,
        uint256 _swingbyPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        address _farmCoin,
        address _farmContract,
        uint256 _ppid
    ) public onlyOwner {
        require(address(swingby) == address(0x0), "failed: init");
        swingby = _swingby;
        swingbyPerBlock = _swingbyPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
        farmCoin = _farmCoin;
        farmContract = _farmContract;
        ppid = _ppid;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accSwingbyPerShare: 0
            })
        );
    }

    // Update the given swingbyPerBlock. Can only be called by the owner.
    function modify(uint256 _swingbyPerBlock) public onlyOwner {
        swingbyPerBlock = _swingbyPerBlock;
    }

    // Update the given pool's SWINGBY allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending SWINGBYs on frontend.
    function pendingSwingby(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSwingbyPerShare = pool.accSwingbyPerShare;
        uint256 lpSupply = totalLockedLPT;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 swingbyReward = multiplier
            .mul(swingbyPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
            accSwingbyPerShare = accSwingbyPerShare.add(
                swingbyReward.mul(1e12).div(lpSupply)
            );
        }
        return
            user.amount.mul(accSwingbyPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = totalLockedLPT;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 swingbyReward = multiplier
        .mul(swingbyPerBlock)
        .mul(pool.allocPoint)
        .div(totalAllocPoint);
        pool.accSwingbyPerShare = pool.accSwingbyPerShare.add(
            swingbyReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to ChefLink for SWINGBYs allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
            .amount
            .mul(pool.accSwingbyPerShare)
            .div(1e12)
            .sub(user.rewardDebt);
            safeSWINGBYTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        if (farmCoin != address(0x0)) {
            // Staking into farming contract.
            _stake(_pid);
            // Send out Earned coins.
            _sendEarnedCoins(_pid, msg.sender);
        }
        // Add total locked amount of LPT
        totalLockedLPT = totalLockedLPT.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accSwingbyPerShare).div(1e12);

        // Send FarmCoins
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from ChefLink.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user
        .amount
        .mul(pool.accSwingbyPerShare)
        .div(1e12)
        .sub(user.rewardDebt);
        safeSWINGBYTransfer(msg.sender, pending);
        if (farmCoin != address(0x0)) {
            // Withdraw LPT and FarmCoins.
            _unStake(_amount);
            // Send out EarnedCoins
            _sendEarnedCoins(_pid, msg.sender);
        }
        // Remove total locked amount of LPT
        totalLockedLPT = totalLockedLPT.sub(_amount);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accSwingbyPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function _stake(uint256 _pid) internal {
        uint256 pendings = IPancakeswapFarm(farmContract).pendingCake(
            ppid,
            address(this)
        );
        toalEarned = toalEarned.add(pendings);
        PoolInfo memory pool = poolInfo[_pid];
        // All amount of LPT will be staked. (includes randomly sent LPT to here.)
        uint256 amount = pool.lpToken.balanceOf(address(this));
        pool.lpToken.safeIncreaseAllowance(farmContract, amount);
        IPancakeswapFarm(farmContract).deposit(ppid, amount);
    }

    function _unStake(uint256 _amount) internal {
        uint256 pendings = IPancakeswapFarm(farmContract).pendingCake(
            ppid,
            address(this)
        );
        toalEarned = toalEarned.add(pendings);
        IPancakeswapFarm(farmContract).withdraw(ppid, _amount);
    }

    function _sendEarnedCoins(uint256 _pid, address _user) internal {
        UserInfo storage user = userInfo[_pid][_user];
        if (totalLockedLPT > 0) {
            uint256 credit = toalEarned.mul(user.amount).div(totalLockedLPT);
            if (user.rewardCoinsDept < credit) {
                uint256 amt = credit.sub(user.rewardCoinsDept);
                IERC20(farmCoin).transfer(msg.sender, amt);
                user.rewardCoinsDept = user.rewardCoinsDept.add(amt);
            }
        }
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY. (TODO: proxy staking)
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (farmCoin != address(0x0)) {
            uint256 pendings = IPancakeswapFarm(farmContract).pendingCake(
                ppid,
                address(this)
            );
            IPancakeswapFarm(farmContract).withdraw(ppid, user.amount);
            IERC20(farmCoin).transfer(owner(), pendings);
        }
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardCoinsDept = 0;
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    // Safe swingby transfer function, just in case if rounding error causes pool to not have enough SWINGBYs.
    function safeSWINGBYTransfer(address _to, uint256 _amount) internal {
        uint256 swingbyBal = swingby.balanceOf(address(this));
        if (_amount > swingbyBal) {
            swingby.transfer(_to, swingbyBal);
        } else {
            swingby.transfer(_to, _amount);
        }
    }
}
