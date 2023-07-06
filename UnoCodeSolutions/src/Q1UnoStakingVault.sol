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
    uint256 public totalInsuranceClaimed; // Total insurance claims

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
        if (user.amount > 0) {
            uint256 pending = getAdjustedStake(msg.sender) * pool.accUnoPerShare / DECIMALS - user.rewardDebt;
            if(pending > 0) {
                safeUnoTransfer(msg.sender, pending);
            }
        }
        totalStakedEth += msg.value;
        user.amount += msg.value;
        user.rewardDebt = getAdjustedStake(msg.sender) * pool.accUnoPerShare / DECIMALS;
        emit Deposit(msg.sender, msg.value);
    }

    /**
    * @notice Allows a user to withdraw their staked ETH
    * @param _amount The amount of ETH to withdraw
    */
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        require(getAdjustedStake(msg.sender) >= _amount, "withdraw: not good");
        _updatePool();
        uint256 pending = getAdjustedStake(msg.sender) * pool.accUnoPerShare / DECIMALS - user.rewardDebt;
        if(pending > 0) {
            safeUnoTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount -= _amount;
            totalStakedEth -= _amount;
            payable(msg.sender).transfer(_amount);
        }
        user.rewardDebt = getAdjustedStake(msg.sender) * pool.accUnoPerShare / DECIMALS;
        emit Withdraw(msg.sender, _amount);
    }

    /**
    * @notice Allows a user to restake their UNO rewards
    */
    function restake() public {
        UserInfo storage user = userInfo[msg.sender];
        _updatePool();
        uint256 pending = getAdjustedStake(msg.sender) * pool.accUnoPerShare / DECIMALS - user.rewardDebt;
        require(pending > 0, "restake: nothing to restake");
        user.amount += pending;
        totalStakedEth += pending;
        user.rewardDebt = getAdjustedStake(msg.sender) * pool.accUnoPerShare / DECIMALS;
        emit Restake(msg.sender, pending);
    }

    /**
    * @notice Updates the reward variables of the pool
    * @dev This should be called every time a user deposits or withdraws ETH
    */
    function _updatePool() internal {
        if (block.number <= startBlock) {
            return;
        }
        uint256 multiplier = block.number - startBlock;
        uint256 unoReward = multiplier * unoPerBlock;
        pool.accUnoPerShare += unoReward * DECIMALS / totalStakedEth;
        pool.lastRewardBlock = block.number;
    }

    /**
    * @notice Sends UNO rewards to a user
    * @param _to The address of the user
    * @param _amount The amount of UNO to send
    */
    function safeUnoTransfer(address _to, uint256 _amount) internal {
        uint256 unoBal = uno.balanceOf(address(this));
        if (_amount > unoBal) {
            uno.transfer(_to, unoBal);
        } else {
            uno.transfer(_to, _amount);
        }
    }

    /**
    * @notice Get the adjusted stake of a user considering insurance claims
    * @param _user The address of the user
    */
    function getAdjustedStake(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 claimRatio = totalInsuranceClaimed * DECIMALS / totalStakedEth;
        uint256 adjustedStake = user.amount * (DECIMALS - claimRatio) / DECIMALS;
        return adjustedStake;
    }

    /**
    * @notice Allows a user to claim their insurance
    * @param _amount The amount of insurance to claim
    */
    function insuranceClaimPayout(uint256 _amount) external onlyOwner {
        uint256 balance = address(this).balance;
        require(_amount <= balance*insuranceClaimLimit/100 );
        totalStakedEth -= _amount; // Update total ETH staked
        totalInsuranceClaimed += amount;
        SafeTransferLib.safeTransferETH(owner(),_amount);
    }

}
