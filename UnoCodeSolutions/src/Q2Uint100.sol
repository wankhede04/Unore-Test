// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

contract StoreNumbers {
    uint256 private numbers;

    function addNumber(uint8 num) public {
        require(num >= 1 && num <= 100, "Number must be between 1 and 100");
        numbers |= (1 << (num - 1));
    }

    function removeNumber(uint8 num) public {
        require(num >= 1 && num <= 100, "Number must be between 1 and 100");
        numbers &= ~(1 << (num - 1));
    }

    function checkNumber(uint8 num) public view returns (bool) {
        require(num >= 1 && num <= 100, "Number must be between 1 and 100");
        return ((numbers >> (num - 1)) & 1) == 1;
    }

    function setAllNumbers() public {
        numbers = (1 << 100) - 1;
    }
}
