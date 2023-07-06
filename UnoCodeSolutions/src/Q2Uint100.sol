// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract StoreNumbers {

    uint256 private currentCount = 0;
    uint256[100] private numbers;

    // Error codes
    error ExceededLimit();
    error InvalidInput();

    function add(uint256 number) public {
        if (currentCount >= 100) {
            revert ExceededLimit();
        }
        numbers[currentCount] = number;
        currentCount++;
    }

    function batchAdd(uint256[] memory batchNumbers) external {
        if (batchNumbers.length == 0 || batchNumbers.length + currentCount > 100) {
            revert InvalidInput();
        }
        uint len = batchNumbers.length
        for (uint256 i; i < len;) {
            add(batchNumbers[i])
            unchecked {
                ++i;
            }
        }
    }

    function getNumber(uint256 index) public view returns (uint256) {
        require(index < currentCount, "Index out of bounds");
        return numbers[index];
    }

    function getAllNumbers() public view returns(uint256[100] memory) {
        return numbers;
    }
}
