// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

contract Oracle {
    address owner;
    uint256 private price;

    constructor(uint256 price_) {
        owner = msg.sender;

        price = price_;
    }

    function setPrice(uint256 newPrice_) external {
        require(msg.sender == owner, "Oracle: only owner");

        price = newPrice_;
    }

    function getPrice() external view returns (uint256) {
        return price;
    }
}
