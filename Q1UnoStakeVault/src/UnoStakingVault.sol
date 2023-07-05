// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUnoToken.sol";
import "./interfaces/IERC20.sol";
import "solady/src/auth/Ownable.sol";
import "solady/src/utils/SafeTransferLib.sol";

/**
 * @title Vault Contract
 * @notice This contract is used to stake Ether and earn UNO rewards.
 * @dev Users can stake their Ether and earn UNO tokens as rewards per block.
 */
contract Vault is Ownable {
    // Information about each staker
    struct UserInfo {
        uint256 amount;     // Amount of ETH staked by the user
        uint256 rewardDebt; // Pending UNO rewards for the user
    }

    // Information about the staking pool
    struct PoolInfo {
        uint256 lastRewardBlock;  // The last block number when UNO rewards were distributed.
        uint256 accUnoPerShare;   // Accumulated UNO rewards per share (times 1e12).
    }

    IUnoToken public uno; // The UNO token contract instance
    IUniswapV2Router02 public uniswapRouter; // The Uniswap Router contract instance

    PoolInfo public pool; // The single staking pool this contract manages
    mapping (address => UserInfo) public userInfo; // Information about each staker

    uint256 public unoPerBlock; // The number of UNO tokens rewarded per block
    uint256 public startBlock; // The block number when staking starts

    uint256 public totalStakedEth; // Total amount of ETH staked in the contract

    uint256 private constant DECIMALS = 1e18;
    uint256 public insuranceClaimLimit; // The maximum percentage of total balance that can be claimed at once

    // Event to be emitted when a user deposits ETH
    event Deposit(address indexed user, uint256 amount);
    // Event to be emitted when a user withdraws their staked ETH
    event Withdraw(address indexed user, uint256 amount);
    // Event to be emitted when a user restakes their UNO rewards
    event Restake(address indexed user, uint256 amount);

    /**
    * @notice Constructor for the Vault contract
    * @param _uno The address of the UNO token contract
    * @param _uniswapRouter The address of the Uniswap router contract
    * @param _unoPerBlock The number of UNO tokens to be rewarded per block
    * @param _startBlock The block number when staking starts
    *@param _insuranceClaimLimit The maximum percentage of total balance that can be claimed at once
    */
    constructor(
        IUnoToken _uno,
        IUniswapV2Router02 _uniswapRouter,
        uint256 _unoPerBlock,
        uint256 _startBlock,
        uint256 _insuranceClaimLimit
    ) {
        uno = _uno;
        uniswapRouter = _uniswapRouter;
        unoPerBlock = _unoPerBlock;
        startBlock = _startBlock;
        insuranceClaimLimit = _insuranceClaimLimit;
    }

    /**
    * @notice Allows a user to deposit ETH into the contract
    * @dev The ETH value should be sent with this function
    */
    function deposit() public payable {
        UserInfo storage user = userInfo[msg.sender];
        _updatePool();

        // If the user has already staked, then automatically restake their rewards
        if (user.amount > 0) {
            uint256 pending = user.amount * pool.accUnoPerShare / DECIMALS - user.rewardDebt;
            if (pending > 0) {
                uint256 restaked = _restakeRewards(msg.sender, pending);
                user.amount += restaked;
                totalStakedEth += restaked;
            }
        }

        user.amount += msg.value;
        user.rewardDebt = user.amount * pool.accUnoPerShare / DECIMALS;

        totalStakedEth += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    /**
    * @notice Allows a user to withdraw their staked ETH
    * @param _amount The amount of ETH to withdraw
    */
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];

        require(user.amount >= _amount, "withdraw: not good");

        _updatePool();

        // Automatically restake any pending rewards before withdrawing
        uint256 pending = user.amount * pool.accUnoPerShare / DECIMALS - user.rewardDebt;
        if (pending > 0) {
            uint256 restaked = _restakeRewards(msg.sender, pending);
            user.amount += restaked;
            totalStakedEth += restaked;
        }

        user.amount -= _amount;
        user.rewardDebt = user.amount * pool.accUnoPerShare / DECIMALS;

        totalStakedEth -= _amount;

        // UNO is a preminted token, therefore safely transferring it here instead of minting it
        // better implementations can be possible
        SafeTransferLib.safeTransferETH(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    /**
    * @notice Updates the staking pool
    * @dev This function is used to distribute the UNO rewards to the stakers
    */
    function _updatePool() internal {
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        uint256 lpSupply = totalStakedEth;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = _getMultiplier(pool.lastRewardBlock, block.number);
        uint256 unoReward = multiplier * unoPerBlock;

        SafeTransferLib.safeTransfer(address(uno), address(this), unoReward);
        pool.accUnoPerShare = pool.accUnoPerShare + unoReward * DECIMALS / lpSupply;
        pool.lastRewardBlock = block.number;
    }

    /**
    * @notice Calculates the number of blocks between two block numbers
    * @param _from The first block number
    * @param _to The second block number
    * @return The number of blocks between the two block numbers
    */
    function _getMultiplier(uint256 _from, uint256 _to) internal pure returns (uint256) {
        return _to - _from;
    }

    /**
    * @notice Restakes the pending UNO rewards of a user
    * @dev The UNO rewards are converted to ETH and staked back into the contract
    * @param _user The address of the user
    * @param _amount The amount of UNO rewards to restake
    * @return The amount of ETH received from swapping the UNO tokens
    */
    function _restakeRewards(address _user, uint256 _amount) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(uno);
        path[1] = uniswapRouter.WETH();

        uint[] memory amountsOut = uniswapRouter.getAmountsOut(_amount, path);
        uint expectedAmountOut = amountsOut[1];

        // Here we assume that Uno is approved to be spent by this contract.
        // If not, Uno should be approved first.
        uno.transferFrom(_user, address(this), _amount);

        uniswapRouter.swapExactTokensForETH(
            _amount,
            expectedAmountOut,
            path,
            address(this),
            block.timestamp
        );

        // Return the actual received amount of Ether
        return expectedAmountOut;
    }

    /**
    * @notice Allows the owner to withdraw Ether for an insurance payout
    * @param _amount The amount of Ether to withdraw
    */
    function insuranceClaimPayout(uint256 _amount) external onlyOwner {
        uint256 balance = address(this).balance;
        require(_amount <= balance*insuranceClaimLimit/100 );
        totalStakedEth -= _amount; // Update total ETH staked
        SafeTransferLib.safeTransferETH(owner(),_amount);
    }
}
