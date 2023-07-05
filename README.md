# Unore-Test

## Setup : 
```
cd ./UnoCodeSolutions
foundryup
forge install
forge build
```
## Solution links
### 1
Please build a Vault smart contract as following.

1. Users stakes ETH and get $UNO rewards based on staking period and the deposited amount.
2. There should be one function which users can re-stake their $UNO reward automatically.
   Please assume there's a ETH-UNO pair on Uniswap V2.
3. There's one admin function called insuranceClaimPayout(uint256 amount) which can take out "amount" of ETH which users depoisted.

https://github.com/wankhede04/Unore-Test/blob/main/UnoCodeSolutions/src/Q1UnoStakingVault.sol

### 2 Please write a smart contract which can store 100 of unit256 variables
https://github.com/wankhede04/Unore-Test/blob/main/UnoCodeSolutions/src/Q2Uint100.sol

### 3 Build a reentrancy smart contract against sellTokenTo function NFTController.sol
https://github.com/wankhede04/Unore-Test/blob/main/UnoCodeSolutions/src/Q3MaliciousBidder.sol

### 4 What function would you use to swap ETH for DAI on the uniswap V2 exchange? What would be the input parameters?
https://github.com/wankhede04/Unore-Test/blob/main/Q4.md

## 5 Can you prove the Sushiswap Masterchef logic mathematically?
https://github.com/wankhede04/Unore-Test/blob/main/Q5.md





