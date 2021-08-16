// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ReentrancyGuard.sol";
import "./interfaces/ISwapContractMin.sol";

contract ChefLinkMaki is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // The Skybridge contract.
    ISwapContractMin public immutable swapContract;
    // The reward token.
    IERC20 public immutable rewardToken;
    // The staked token.
    IERC20 public immutable stakedToken;
    // The BTCT address.
    address public immutable BTCT_ADDR;
    // Accrued token per share.
    uint256 public accTokenPerShare;
    // The block number when token distribute ends.
    uint256 public bonusEndBlock;
    // The block number when token distribute starts.
    uint256 public startBlock;
    // The block number of the last pool update.
    uint256 public lastRewardBlock;
    // Tokens per block.
    uint256 public rewardPerBlock;
    // default param that for rewardPerBlock.
    uint256 public defaultRewardPerBlock;
    // the maximum size of rewardPerBlock.
    uint256 public maxRewardPerBlock;
    // A falg for dynamic changing ths rewardPerBlock.
    bool public isDynamic = true;
    // The flag for active BTC pool.
    bool public isDynamicBTC;
    // The flag for active BTCT pool.
    bool public isDynamicBTCT;
    // latest tilt size which is updated when updated pool.
    uint256 public latestTilt;
    // Info of each user that stakes tokens (stakedToken).
    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 rewardDebt; // Reward debt
    }

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);
    event NewRewardPerBlock(uint256 rewardPerBlock);
    event NewPoolLimit(uint256 poolLimitPerUser);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount);

    constructor(
        IERC20 _stakedToken,
        IERC20 _rewardToken,
        ISwapContractMin _swapContract,
        address _btct,
        uint256 _rewardPerBlock,
        uint256 _maxRewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        defaultRewardPerBlock = rewardPerBlock;
        require(_maxRewardPerBlock >= _rewardPerBlock);
        maxRewardPerBlock = _maxRewardPerBlock;
        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;
        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;
        // Sst Skybridge contract
        swapContract = _swapContract;
        // Set BTCT
        BTCT_ADDR = _btct;
    }

    /**
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function deposit(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        _updatePool();

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(accTokenPerShare).div(1e12).sub(
                user.rewardDebt
            );
            if (pending > 0) {
                rewardToken.safeTransfer(address(msg.sender), pending);
            }
        }

        if (_amount > 0) {
            user.amount = user.amount.add(_amount);
            stakedToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
        }

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(1e12);

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Amount to withdraw too high");

        _updatePool();

        uint256 pending = user.amount.mul(accTokenPerShare).div(1e12).sub(
            user.rewardDebt
        );

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            stakedToken.safeTransfer(address(msg.sender), _amount);
        }

        if (pending > 0) {
            rewardToken.safeTransfer(address(msg.sender), pending);
        }

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(1e12);

        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @notice Withdraw staked tokens without caring about rewards rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amountToTransfer = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        if (amountToTransfer > 0) {
            stakedToken.safeTransfer(address(msg.sender), amountToTransfer);
        }

        emit EmergencyWithdraw(msg.sender, user.amount);
    }

    /**
     * @notice Stop rewards
     * @dev Only callable by owner. Needs to be for emergency.
     */
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        rewardToken.safeTransfer(address(msg.sender), _amount);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount)
        external
        onlyOwner
    {
        require(
            _tokenAddress != address(stakedToken),
            "Cannot be staked token"
        );
        require(
            _tokenAddress != address(rewardToken),
            "Cannot be reward token"
        );

        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice Stop rewards
     * @dev Only callable by owner
     */
    function stopReward() external onlyOwner {
        bonusEndBlock = block.number;
    }

    /**
     * @notice Update reward per block
     * @dev Only callable by owner.
     * @param _rewardPerBlock: the reward per block
     */
    function updateRewardPerBlock(
        uint256 _rewardPerBlock,
        uint256 _maxRewardPerBlock,
        bool _isDynamic
    ) external onlyOwner {
        require(_rewardPerBlock >= 1e17);
        require(_rewardPerBlock <= 3e18);
        require(_maxRewardPerBlock >= _rewardPerBlock);
        rewardPerBlock = _rewardPerBlock;
        defaultRewardPerBlock = rewardPerBlock;
        maxRewardPerBlock = _maxRewardPerBlock;
        isDynamic = _isDynamic;
        emit NewRewardPerBlock(_rewardPerBlock);
    }

    /**
     * @notice It allows the admin to update start and end blocks
     * @dev This function is only callable by owner.
     * @param _startBlock: the new start block
     * @param _bonusEndBlock: the new end block
     */
    function updateStartAndEndBlocks(
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        require(
            _startBlock < _bonusEndBlock,
            "New startBlock must be lower than new endBlock"
        );
        require(
            block.number < _startBlock,
            "New startBlock must be higher than current block"
        );

        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;

        emit NewStartAndEndBlocks(_startBlock, _bonusEndBlock);
    }

    /**
     * @notice Update bonusEndBlock of the given pool to be up-to-date.
     * @param _bonusEndBlock: next bonusEndBlock
     */

    function updateEndBlocks(uint256 _bonusEndBlock) external onlyOwner {
        require(
            block.number < _bonusEndBlock,
            "New bonusEndBlock must be higher than current height"
        );
        bonusEndBlock = _bonusEndBlock;
    }

    /**
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));
        if (block.number > lastRewardBlock && stakedTokenSupply != 0) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            uint256 tokenReward = multiplier.mul(rewardPerBlock);
            uint256 adjustedTokenPerShare = accTokenPerShare.add(
                tokenReward.mul(1e12).div(stakedTokenSupply)
            );
            return
                user.amount.mul(adjustedTokenPerShare).div(1e12).sub(
                    user.rewardDebt
                );
        } else {
            return
                user.amount.mul(accTokenPerShare).div(1e12).sub(
                    user.rewardDebt
                );
        }
    }

    /**
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }
        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));

        if (stakedTokenSupply == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(rewardPerBlock);
        accTokenPerShare = accTokenPerShare.add(
            tokenReward.mul(1e12).div(stakedTokenSupply)
        );
        if (isDynamic) _updateRewardPerBlock();
        lastRewardBlock = block.number;
    }

    /**
     * @notice View function to see next expected rewardPerBlock on frontend.
     * @param _token: token address which is supported on Swingby Skybridge.
     * @param _amountOfFloat: a float amount when deposited on skybridge in the future.
     */

    function getExpectedRewardPerBlock(address _token, uint256 _amountOfFloat)
        public
        view
        returns (
            uint256 updatedRewards,
            uint256 reserveBTC,
            uint256 reserveBTCT,
            uint256 tilt
        )
    {
        uint256 blocks = block.number - lastRewardBlock != 0
            ? block.number.sub(lastRewardBlock)
            : 1;

        updatedRewards = rewardPerBlock;
        (reserveBTC, reserveBTCT) = swapContract.getFloatReserve(
            address(0),
            BTCT_ADDR
        );

        require(_token == address(0x0) || _token == BTCT_ADDR);

        if (_token == address(0x0)) reserveBTC = reserveBTC.add(_amountOfFloat);
        else reserveBTCT = reserveBTCT.add(_amountOfFloat);

        tilt = (reserveBTC >= reserveBTCT)
            ? reserveBTC.sub(reserveBTCT)
            : reserveBTCT.sub(reserveBTC);

        if ((isDynamicBTC || isDynamicBTCT) && isDynamic)
            if (latestTilt > tilt) {
                updatedRewards = rewardPerBlock.add(
                    latestTilt.sub(tilt).mul(1e10).div(blocks)
                ); // moved == decimals 8
            } else {
                updatedRewards = rewardPerBlock.sub(
                    tilt.sub(latestTilt).mul(1e10).div(blocks)
                ); // moved == decimals 8
            }

        if (updatedRewards >= maxRewardPerBlock) {
            updatedRewards = maxRewardPerBlock;
        }
        if (updatedRewards <= defaultRewardPerBlock) {
            updatedRewards = defaultRewardPerBlock;
        }
        return (updatedRewards, reserveBTC, reserveBTCT, tilt);
    }

    /**
     * @notice Update rewardPerBlock
     */
    function _updateRewardPerBlock() internal {
        (
            uint256 updatedRewards,
            uint256 reserveBTC,
            uint256 reserveBTCT,
            uint256 tilt
        ) = getExpectedRewardPerBlock(address(0x0), 0); // check the current numbers.

        rewardPerBlock = updatedRewards;

        // Reback the rate is going to be posive after reached to a threshold.
        if (reserveBTC >= reserveBTCT && isDynamicBTC) {
            // Disable additonal rewards rate for btc
            isDynamicBTC = false;
            rewardPerBlock = defaultRewardPerBlock;
        }

        // Reback the rate is going to be negative after reached to a threshold.
        if (reserveBTCT >= reserveBTC && isDynamicBTCT) {
            // Disable additonal rewards rate for btct
            isDynamicBTCT = false;
            rewardPerBlock = defaultRewardPerBlock;
        }

        // Check the deposit fees rate for checking the tilt of float balances
        uint256 feesForDepositBTC = swapContract.getDepositFeeRate(
            address(0x0),
            0
        );
        uint256 feesForDepositBTCT = swapContract.getDepositFeeRate(
            BTCT_ADDR,
            0
        );

        // if the deposit fees for BTC are exist, have to be activated isDynamicBTCT
        if (feesForDepositBTC != 0) {
            isDynamicBTCT = true;
        }
        // if the deposit fees for BTC are exist, have to be activated isDynamicBTC
        if (feesForDepositBTCT != 0) {
            isDynamicBTC = true;
        }
        latestTilt = tilt;
    }

    /**
     * @notice Return reward multiplier over the given _from to _to block.
     * @param _from: block to start
     * @param _to: block to finish
     */
    function _getMultiplier(uint256 _from, uint256 _to)
        internal
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from);
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock.sub(_from);
        }
    }
}
